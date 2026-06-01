import { createId } from '@paralleldrive/cuid2';
import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { PostEventCheckIn } from '../../domain/entities/post-event-check-in.js';
import { FlagCheckInUseCase } from './flag-check-in.usecase.js';
import {
  FakeEventPublisher,
  FakePostEventCheckInRepository,
  FakeRecordPostEventCheckInEventUseCase,
  FakeUnitOfWork,
  FixedClock,
  TEST_TX,
} from './fakes.js';

const NOW = new Date('2026-05-19T12:00:00Z');
const ATTENDEE_ID = 'user_attendee_1';
const HOST_ID = 'user_host_1';
const EVENT_ID = 'event_1';

/** Build and persist a pending check-in in the fake repo. */
const seedPending = (repo: FakePostEventCheckInRepository): PostEventCheckIn => {
  const checkIn = PostEventCheckIn.create({
    id: createId(),
    userId: ATTENDEE_ID,
    eventId: EVENT_ID,
    hostUserId: HOST_ID,
    now: new Date(NOW.getTime() - 60_000),
  });
  checkIn.pullEvents(); // discard — simulating already-persisted state
  repo.put(checkIn);
  return checkIn;
};

const buildSut = () => {
  const checkIns = new FakePostEventCheckInRepository();
  const publisher = new FakeEventPublisher();
  const recorder = new FakeRecordPostEventCheckInEventUseCase();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new FlagCheckInUseCase(uow, checkIns, publisher, recorder, clock);
  return { checkIns, publisher, recorder, useCase };
};

describe('FlagCheckInUseCase', () => {
  it('transitions pending → flagged and returns { ok: true }', async () => {
    const { checkIns, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    const result = await useCase.execute({
      id: checkIn.id,
      userId: ATTENDEE_ID,
      reportBody: 'Host was rude and I felt unsafe at the venue.',
      disclaimerAcknowledged: true,
    });

    expect(result).toEqual({ ok: true });
    const stored = await checkIns.findById(checkIn.id);
    expect(stored?.status).toBe('flagged');
    expect(stored?.reportBody).toBe('Host was rude and I felt unsafe at the venue.');
    expect(stored?.flaggedAt).toEqual(NOW);
    expect(stored?.disclaimerAcknowledged).toBe(true);
  });

  it('publishes the checkInFlagged domain event', async () => {
    const { checkIns, publisher, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    await useCase.execute({
      id: checkIn.id,
      userId: ATTENDEE_ID,
      reportBody: 'Unsafe',
      disclaimerAcknowledged: true,
    });

    expect(publisher.published).toHaveLength(1);
    expect(publisher.published[0]?.type).toContain('checkInFlagged');
  });

  it('records audit event with reason flagged and correct ids', async () => {
    const { checkIns, recorder, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    await useCase.execute({
      id: checkIn.id,
      userId: ATTENDEE_ID,
      reportBody: 'Bad experience',
      disclaimerAcknowledged: true,
    });

    expect(recorder.calls).toHaveLength(1);
    const call = recorder.calls[0];
    expect(call?.input.reason).toBe('flagged');
    expect(call?.input.checkInId).toBe(checkIn.id);
    expect(call?.input.userId).toBe(ATTENDEE_ID);
    expect(call?.input.eventId).toBe(EVENT_ID);
    expect(call?.ctx).toBe(TEST_TX);
  });

  it('throws NOT_FOUND when the check-in does not exist', async () => {
    const { useCase } = buildSut();

    try {
      await useCase.execute({
        id: 'missing',
        userId: ATTENDEE_ID,
        reportBody: 'Something',
        disclaimerAcknowledged: true,
      });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).code).toBe('NOT_FOUND');
    }
  });

  it('throws FORBIDDEN when userId does not match the check-in attendee', async () => {
    const { checkIns, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    try {
      await useCase.execute({
        id: checkIn.id,
        userId: 'someone-else',
        reportBody: 'Bad',
        disclaimerAcknowledged: true,
      });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).code).toBe('FORBIDDEN');
    }
  });

  it('throws UNPROCESSABLE disclaimerNotAcknowledged when disclaimerAcknowledged is false', async () => {
    const { checkIns, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    try {
      await useCase.execute({
        id: checkIn.id,
        userId: ATTENDEE_ID,
        reportBody: 'I felt unsafe.',
        disclaimerAcknowledged: false,
      });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).code).toBe('UNPROCESSABLE');
      expect((err as AppError).details).toEqual({ subcode: 'check-ins.disclaimerNotAcknowledged' });
    }
  });

  it('throws UNPROCESSABLE REPORT_EMPTY when reportBody is blank', async () => {
    const { checkIns, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    try {
      await useCase.execute({
        id: checkIn.id,
        userId: ATTENDEE_ID,
        reportBody: '   ',
        disclaimerAcknowledged: true,
      });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).code).toBe('UNPROCESSABLE');
      expect((err as AppError).details).toEqual({ subcode: 'REPORT_EMPTY' });
    }
  });

  it('throws UNPROCESSABLE REPORT_TOO_LONG when reportBody exceeds 2000 chars', async () => {
    const { checkIns, useCase } = buildSut();
    const checkIn = seedPending(checkIns);
    const longBody = 'x'.repeat(2001);

    try {
      await useCase.execute({
        id: checkIn.id,
        userId: ATTENDEE_ID,
        reportBody: longBody,
        disclaimerAcknowledged: true,
      });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).code).toBe('UNPROCESSABLE');
      expect((err as AppError).details).toEqual({ subcode: 'REPORT_TOO_LONG' });
    }
  });

  it('throws CONFLICT when the check-in is already acknowledged', async () => {
    const { checkIns, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    // Transition to acknowledged first.
    checkIn.acknowledge({ now: new Date(NOW.getTime() - 30_000) });
    checkIn.pullEvents();
    checkIns.put(checkIn);

    try {
      await useCase.execute({
        id: checkIn.id,
        userId: ATTENDEE_ID,
        reportBody: 'Changed mind',
        disclaimerAcknowledged: true,
      });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).code).toBe('CONFLICT');
    }
  });

  it('throws CONFLICT when the check-in is already flagged', async () => {
    const { checkIns, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    // Transition to flagged first.
    checkIn.flag({
      reportBody: 'First report',
      disclaimerAcknowledged: true,
      now: new Date(NOW.getTime() - 30_000),
    });
    checkIn.pullEvents();
    checkIns.put(checkIn);

    try {
      await useCase.execute({
        id: checkIn.id,
        userId: ATTENDEE_ID,
        reportBody: 'Second report',
        disclaimerAcknowledged: true,
      });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).code).toBe('CONFLICT');
    }
  });
});
