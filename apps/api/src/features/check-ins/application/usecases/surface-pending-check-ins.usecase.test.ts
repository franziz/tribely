import { createId } from '@paralleldrive/cuid2';
import { describe, expect, it } from 'vitest';
import { PostEventCheckIn } from '../../domain/entities/post-event-check-in.js';
import { SurfacePendingCheckInsUseCase } from './surface-pending-check-ins.usecase.js';
import {
  FakeEventPublisher,
  FakeEventRepository,
  FakePostEventCheckInRepository,
  FakeRecordPostEventCheckInEventUseCase,
  FakeUnitOfWork,
  FakeUserRepository,
  FixedClock,
} from './fakes.js';
import { Event } from '@/features/events/domain/entities/event.js';
import { User } from '@/features/users/domain/entities/user.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Capacity } from '@/features/events/domain/value-objects/capacity.js';
import { EventCategory } from '@/features/events/domain/value-objects/event-category.js';
import { Venue } from '@/features/events/domain/value-objects/venue.js';
import { VenueCategory } from '@/features/events/domain/value-objects/venue-category.js';

const NOW = new Date('2026-05-19T12:00:00Z');
const ENDS_AT_RECENT = new Date(NOW.getTime() - 4 * 60 * 60 * 1000); // 4h ago (in window)
const STARTS_AT = new Date(ENDS_AT_RECENT.getTime() - 3 * 60 * 60 * 1000);

const ATTENDEE_ID = 'user_attendee_1';
const HOST_ID = 'user_host_1';
const EVENT_ID = 'event_1';

const TEST_VENUE = Venue.create({
  address: '3 River Valley Rd, Singapore',
  city: 'Singapore',
  latitude: 1.2906,
  longitude: 103.8465,
});
const TEST_VENUE_CATEGORY = VenueCategory.create('bar');

const makeEvent = (overrides: { title?: string } = {}): Event => {
  return Event.rehydrate({
    id: EVENT_ID,
    hostUserId: HOST_ID,
    title: overrides.title ?? 'Drinks at Clarke Quay',
    description: null,
    venue: TEST_VENUE,
    venueCategory: TEST_VENUE_CATEGORY,
    startsAt: STARTS_AT,
    endsAt: ENDS_AT_RECENT,
    capacity: Capacity.create(8),
    category: EventCategory.create('food'),
    costNotes: null,
    approvalMode: 'manual',
    status: 'completed',
    cancellationReason: null,
    createdAt: new Date(NOW.getTime() - 7 * 24 * 60 * 60 * 1000),
    updatedAt: new Date(NOW.getTime() - 7 * 24 * 60 * 60 * 1000),
  });
};

const makeHost = (): User => {
  return User.register({
    id: HOST_ID,
    email: Email.create('host@tri29.test'),
    displayName: DisplayName.create('TRI-29 Host'),
    now: NOW,
  });
};

const buildSut = () => {
  const checkIns = new FakePostEventCheckInRepository();
  const eventRepo = new FakeEventRepository();
  const userRepo = new FakeUserRepository();
  const publisher = new FakeEventPublisher();
  const recorder = new FakeRecordPostEventCheckInEventUseCase();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new SurfacePendingCheckInsUseCase(
    uow,
    checkIns,
    eventRepo,
    userRepo,
    publisher,
    recorder,
    clock,
  );
  return { checkIns, eventRepo, userRepo, publisher, recorder, useCase };
};

describe('SurfacePendingCheckInsUseCase', () => {
  it('creates a check-in for each approved attendance without one and returns pending list', async () => {
    const { checkIns, eventRepo, userRepo, publisher, recorder, useCase } = buildSut();

    checkIns.setAttendances([{ eventId: EVENT_ID, hostUserId: HOST_ID }]);
    eventRepo.put(makeEvent());
    userRepo.put(makeHost());

    const result = await useCase.execute({ userId: ATTENDEE_ID });

    expect(result.items).toHaveLength(1);
    const item = result.items[0];
    expect(item?.eventId).toBe(EVENT_ID);
    expect(item?.eventTitle).toBe('Drinks at Clarke Quay');
    expect(item?.hostDisplayName).toBe('TRI-29 Host');
    expect(item?.endedAt).toEqual(ENDS_AT_RECENT);

    // Check-in was persisted
    expect(checkIns.all()).toHaveLength(1);
    expect(checkIns.all()[0]?.status).toBe('pending');

    // Domain event was published
    expect(publisher.published).toHaveLength(1);
    expect(publisher.published[0]?.type).toContain('checkInCreated');

    // Audit record was written with reason 'created'
    expect(recorder.calls).toHaveLength(1);
    expect(recorder.calls[0]?.input.reason).toBe('created');
    expect(recorder.calls[0]?.input.userId).toBe(ATTENDEE_ID);
    expect(recorder.calls[0]?.input.eventId).toBe(EVENT_ID);
  });

  it('returns empty items when there are no approved attendances without check-in', async () => {
    const { useCase } = buildSut();
    // FakePostEventCheckInRepository defaults to [] attendances
    const result = await useCase.execute({ userId: ATTENDEE_ID });
    expect(result.items).toHaveLength(0);
  });

  it('truncates event titles longer than 40 chars with ellipsis', async () => {
    const { checkIns, eventRepo, userRepo, useCase } = buildSut();

    checkIns.setAttendances([{ eventId: EVENT_ID, hostUserId: HOST_ID }]);
    eventRepo.put(
      makeEvent({ title: 'This Is A Very Long Event Title That Exceeds Forty Characters Easily' }),
    );
    userRepo.put(makeHost());

    const result = await useCase.execute({ userId: ATTENDEE_ID });

    expect(result.items[0]?.eventTitle).toHaveLength(41); // 40 chars + '…'
    expect(result.items[0]?.eventTitle.endsWith('…')).toBe(true);
  });

  it('does not create duplicate check-ins when called twice (idempotency via no attendances returned second time)', async () => {
    const { checkIns, eventRepo, userRepo, useCase } = buildSut();

    // First call has one attendance to create.
    checkIns.setAttendances([{ eventId: EVENT_ID, hostUserId: HOST_ID }]);
    eventRepo.put(makeEvent());
    userRepo.put(makeHost());

    await useCase.execute({ userId: ATTENDEE_ID });

    // Second call returns no attendances — the DB won't return already-created ones.
    checkIns.setAttendances([]);
    const secondResult = await useCase.execute({ userId: ATTENDEE_ID });

    // Still returns the one pending check-in from the first call.
    expect(secondResult.items).toHaveLength(1);
    // Only one check-in row total.
    expect(checkIns.all()).toHaveLength(1);
  });

  it('returns existing pending check-ins even when no new ones are created', async () => {
    const { checkIns, eventRepo, userRepo, useCase } = buildSut();

    // Pre-seed an existing pending check-in.
    const existing = PostEventCheckIn.create({
      id: createId(),
      userId: ATTENDEE_ID,
      eventId: EVENT_ID,
      hostUserId: HOST_ID,
      now: new Date(NOW.getTime() - 60_000),
    });
    existing.pullEvents(); // discard — already persisted state
    checkIns.put(existing);

    checkIns.setAttendances([]); // no new ones to create
    eventRepo.put(makeEvent());
    userRepo.put(makeHost());

    const result = await useCase.execute({ userId: ATTENDEE_ID });

    expect(result.items).toHaveLength(1);
    expect(result.items[0]?.id).toBe(existing.id);
  });
});
