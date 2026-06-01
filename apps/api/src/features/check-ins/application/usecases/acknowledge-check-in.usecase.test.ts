import { createId } from '@paralleldrive/cuid2';
import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { PostEventCheckIn } from '../../domain/entities/post-event-check-in.js';
import { AcknowledgeCheckInUseCase } from './acknowledge-check-in.usecase.js';
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
  const useCase = new AcknowledgeCheckInUseCase(uow, checkIns, publisher, recorder, clock);
  return { checkIns, publisher, recorder, useCase };
};

describe('AcknowledgeCheckInUseCase', () => {
  it('transitions pending → ok and returns { ok: true }', async () => {
    const { checkIns, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    const result = await useCase.execute({ id: checkIn.id, userId: ATTENDEE_ID });

    expect(result).toEqual({ ok: true });
    const stored = await checkIns.findById(checkIn.id);
    expect(stored?.status).toBe('ok');
    expect(stored?.acknowledgedAt).toEqual(NOW);
  });

  it('publishes the checkInAcknowledged domain event', async () => {
    const { checkIns, publisher, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    await useCase.execute({ id: checkIn.id, userId: ATTENDEE_ID });

    expect(publisher.published).toHaveLength(1);
    expect(publisher.published[0]?.type).toContain('checkInAcknowledged');
  });

  it('records audit event with reason acknowledged and correct ids', async () => {
    const { checkIns, recorder, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    await useCase.execute({ id: checkIn.id, userId: ATTENDEE_ID });

    expect(recorder.calls).toHaveLength(1);
    const call = recorder.calls[0];
    expect(call?.input.reason).toBe('acknowledged');
    expect(call?.input.checkInId).toBe(checkIn.id);
    expect(call?.input.userId).toBe(ATTENDEE_ID);
    expect(call?.input.eventId).toBe(EVENT_ID);
    expect(call?.ctx).toBe(TEST_TX);
  });

  it('throws NOT_FOUND when the check-in does not exist', async () => {
    const { useCase } = buildSut();
    await expect(useCase.execute({ id: 'missing', userId: ATTENDEE_ID })).rejects.toThrowError(
      AppError,
    );

    try {
      await useCase.execute({ id: 'missing', userId: ATTENDEE_ID });
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
      await useCase.execute({ id: checkIn.id, userId: 'someone-else' });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).code).toBe('FORBIDDEN');
    }
  });

  it('throws CONFLICT when the check-in is already acknowledged', async () => {
    const { checkIns, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    // Acknowledge once successfully.
    await useCase.execute({ id: checkIn.id, userId: ATTENDEE_ID });

    // Second acknowledgement must fail with CONFLICT.
    try {
      await useCase.execute({ id: checkIn.id, userId: ATTENDEE_ID });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).code).toBe('CONFLICT');
    }
  });

  it('throws CONFLICT when the check-in is in flagged status', async () => {
    const { checkIns, useCase } = buildSut();
    const checkIn = seedPending(checkIns);

    // Transition to flagged via the aggregate directly.
    checkIn.flag({
      reportBody: 'Unsafe',
      disclaimerAcknowledged: true,
      now: new Date(NOW.getTime() - 30_000),
    });
    checkIn.pullEvents();
    checkIns.put(checkIn); // upsert the updated state

    try {
      await useCase.execute({ id: checkIn.id, userId: ATTENDEE_ID });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).code).toBe('CONFLICT');
    }
  });
});
