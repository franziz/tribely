import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Event } from '@/features/events/domain/entities/event.js';
import { Capacity } from '@/features/events/domain/value-objects/capacity.js';
import { EventCategory } from '@/features/events/domain/value-objects/event-category.js';
import { VenueCategory } from '@/features/events/domain/value-objects/venue-category.js';
import { Venue } from '@/features/events/domain/value-objects/venue.js';
import { JoinRequest } from '../../domain/entities/join-request.js';
import { JOIN_REQUEST_APPROVED } from '../../domain/events/approved.event.js';
import { ApproveJoinRequestUseCase } from './approve-join-request.usecase.js';
import {
  FakeEventPublisher,
  FakeEventRepository,
  FakeJoinRequestRepository,
  FakeUnitOfWork,
  FixedClock,
} from './fakes.js';

const NOW = new Date('2026-05-11T00:00:00Z');
const STARTS = new Date(NOW.getTime() + 7 * 24 * 60 * 60 * 1000);
const ENDS = new Date(STARTS.getTime() + 3 * 60 * 60 * 1000);

const SNAPSHOT = {
  startsAt: STARTS,
  endsAt: ENDS,
  venue: { address: '18 Raffles Quay', city: 'Singapore', latitude: 1.2806, longitude: 103.8504 },
  hostUserId: 'host_1',
};

const seedEvent = (repo: FakeEventRepository, capacity = 4): Event => {
  const event = Event.create({
    id: 'evt_1',
    hostUserId: 'host_1',
    title: 'Hawker tour',
    description: null,
    venue: Venue.create(SNAPSHOT.venue),
    startsAt: STARTS,
    endsAt: ENDS,
    capacity: Capacity.create(capacity),
    category: EventCategory.create('food'),
    venueCategory: VenueCategory.create('cafe'),
    costSplit: 'own',
    approvalMode: 'manual',
    now: NOW,
  });
  event.publish(NOW);
  event.pullEvents();
  repo.put(event);
  return event;
};

const seedPending = (
  repo: FakeJoinRequestRepository,
  overrides: Partial<{ id: string; requesterUserId: string }> = {},
): JoinRequest => {
  const jr = JoinRequest.request({
    id: overrides.id ?? 'jr_1',
    eventId: 'evt_1',
    requesterUserId: overrides.requesterUserId ?? 'requester_1',
    now: NOW,
    autoApprove: false,
    hostUserId: 'host_1',
    eventSnapshot: SNAPSHOT,
  });
  jr.pullEvents();
  repo.put(jr);
  return jr;
};

const seedApproved = (repo: FakeJoinRequestRepository, id: string, requesterUserId: string) => {
  const jr = JoinRequest.request({
    id,
    eventId: 'evt_1',
    requesterUserId,
    now: NOW,
    autoApprove: true,
    hostUserId: 'host_1',
    eventSnapshot: SNAPSHOT,
  });
  jr.pullEvents();
  repo.put(jr);
};

const buildSut = () => {
  const events = new FakeEventRepository();
  const joinRequests = new FakeJoinRequestRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new ApproveJoinRequestUseCase(uow, joinRequests, events, publisher, clock);
  return { events, joinRequests, publisher, useCase };
};

describe('ApproveJoinRequestUseCase', () => {
  it('approves a pending request and emits joinRequests.approved with full snapshot', async () => {
    const { events, joinRequests, publisher, useCase } = buildSut();
    seedEvent(events);
    seedPending(joinRequests);

    const jr = await useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'host_1' });

    expect(jr.status).toBe('approved');
    expect(jr.decidedByUserId).toBe('host_1');
    expect(publisher.published).toHaveLength(1);
    const ev = publisher.published[0];
    expect(ev?.type).toBe(JOIN_REQUEST_APPROVED);
    expect(ev?.payload).toMatchObject({
      id: 'jr_1',
      eventId: 'evt_1',
      requesterUserId: 'requester_1',
      approvedByUserId: 'host_1',
      hostUserId: 'host_1',
      eventStartsAt: STARTS.toISOString(),
      eventEndsAt: ENDS.toISOString(),
      eventVenue: SNAPSHOT.venue,
    });
  });

  it('returns 404 when the join request does not exist', async () => {
    const { events, useCase } = buildSut();
    seedEvent(events);
    await expect(
      useCase.execute({ joinRequestId: 'missing', actorUserId: 'host_1' }),
    ).rejects.toThrowError(AppError);
  });

  it('forbids approval by anyone other than the host', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    seedPending(joinRequests);
    await expect(
      useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'someone-else' }),
    ).rejects.toThrowError(/host/);
  });

  it('throws CAPACITY_FULL when approved count is at capacity - 1', async () => {
    const { events, joinRequests, useCase } = buildSut();
    // capacity=3 → 2 requester seats. Pre-seed 2 approved → full.
    seedEvent(events, 3);
    seedApproved(joinRequests, 'jr_a', 'u_a');
    seedApproved(joinRequests, 'jr_b', 'u_b');
    seedPending(joinRequests, { id: 'jr_late', requesterUserId: 'u_late' });

    try {
      await useCase.execute({ joinRequestId: 'jr_late', actorUserId: 'host_1' });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      const e = err as AppError;
      expect(e.code).toBe('CONFLICT');
      expect(e.details).toEqual({ subcode: 'CAPACITY_FULL' });
    }
  });

  it('propagates ALREADY_APPROVED from the aggregate on re-approve', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events, 10);
    seedApproved(joinRequests, 'jr_1', 'requester_1');

    try {
      await useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'host_1' });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      const e = err as AppError;
      expect(e.code).toBe('CONFLICT');
      expect(e.details).toEqual({ subcode: 'ALREADY_APPROVED' });
    }
  });
});
