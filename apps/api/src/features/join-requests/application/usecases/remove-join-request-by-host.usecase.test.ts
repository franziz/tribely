import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Event } from '@/features/events/domain/entities/event.js';
import { Capacity } from '@/features/events/domain/value-objects/capacity.js';
import { EventCategory } from '@/features/events/domain/value-objects/event-category.js';
import { VenueCategory } from '@/features/events/domain/value-objects/venue-category.js';
import { Venue } from '@/features/events/domain/value-objects/venue.js';
import { JoinRequest } from '../../domain/entities/join-request.js';
import { JOIN_REQUEST_REMOVED_BY_HOST } from '../../domain/events/removed-by-host.event.js';
import { RemoveJoinRequestByHostUseCase } from './remove-join-request-by-host.usecase.js';
import {
  FakeEventPublisher,
  FakeEventRepository,
  FakeJoinRequestRepository,
  FakeUnitOfWork,
  FixedClock,
  TEST_TX,
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

const seedEvent = (repo: FakeEventRepository): Event => {
  const event = Event.create({
    id: 'evt_1',
    hostUserId: 'host_1',
    title: 'Hawker tour',
    description: null,
    venue: Venue.create(SNAPSHOT.venue),
    startsAt: STARTS,
    endsAt: ENDS,
    capacity: Capacity.create(6),
    category: EventCategory.create('food'),
    venueCategory: VenueCategory.create('cafe'),
    costNotes: null,
    approvalMode: 'manual',
    now: NOW,
  });
  event.publish(NOW);
  event.pullEvents();
  repo.put(event);
  return event;
};

/** Seeds an approved JR (via auto-approve so no separate approve step needed). */
const seedApproved = (
  repo: FakeJoinRequestRepository,
  overrides: Partial<{ id: string; requesterUserId: string }> = {},
): JoinRequest => {
  const jr = JoinRequest.request({
    id: overrides.id ?? 'jr_1',
    eventId: 'evt_1',
    requesterUserId: overrides.requesterUserId ?? 'requester_1',
    now: NOW,
    autoApprove: true,
    hostUserId: 'host_1',
    eventSnapshot: SNAPSHOT,
  });
  jr.pullEvents();
  repo.put(jr);
  return jr;
};

/** Seeds a pending (non-approved) JR. */
const seedPending = (repo: FakeJoinRequestRepository, id = 'jr_pending'): JoinRequest => {
  const jr = JoinRequest.request({
    id,
    eventId: 'evt_1',
    requesterUserId: 'requester_2',
    now: NOW,
    autoApprove: false,
    hostUserId: 'host_1',
    eventSnapshot: SNAPSHOT,
  });
  jr.pullEvents();
  repo.put(jr);
  return jr;
};

const buildSut = () => {
  const events = new FakeEventRepository();
  const joinRequests = new FakeJoinRequestRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new RemoveJoinRequestByHostUseCase(uow, joinRequests, events, publisher, clock);
  return { events, joinRequests, publisher, useCase };
};

describe('RemoveJoinRequestByHostUseCase', () => {
  it('removes an approved JR and emits joinRequests.removedByHost with reason persisted', async () => {
    const { events, joinRequests, publisher, useCase } = buildSut();
    seedEvent(events);
    seedApproved(joinRequests);

    const jr = await useCase.execute({
      joinRequestId: 'jr_1',
      actorUserId: 'host_1',
      reason: '  bad behaviour  ',
    });

    expect(jr.status).toBe('removed_by_host');
    expect(jr.decidedByUserId).toBe('host_1');
    expect(jr.decisionReason).toBe('bad behaviour');
    expect(publisher.published).toHaveLength(1);
    const ev = publisher.published[0];
    expect(ev?.type).toBe(JOIN_REQUEST_REMOVED_BY_HOST);
    expect(ev?.payload).toMatchObject({
      id: 'jr_1',
      eventId: 'evt_1',
      requesterUserId: 'requester_1',
      removedByUserId: 'host_1',
      hostUserId: 'host_1',
      reason: 'bad behaviour',
    });
  });

  it('uses the transaction context for the JR repository call', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    seedApproved(joinRequests);

    await useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'host_1', reason: 'reason' });

    expect(joinRequests.lastFindByIdCtx).toBe(TEST_TX);
  });

  it('returns 404 when the join request does not exist', async () => {
    const { events, useCase } = buildSut();
    seedEvent(events);
    await expect(
      useCase.execute({ joinRequestId: 'missing', actorUserId: 'host_1', reason: 'reason' }),
    ).rejects.toThrowError(AppError);
  });

  it('returns 404 when the parent event does not exist (defensive)', async () => {
    const { joinRequests, useCase } = buildSut();
    // No event seeded — simulate data corruption.
    seedApproved(joinRequests);
    await expect(
      useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'host_1', reason: 'reason' }),
    ).rejects.toThrowError(AppError);
  });

  it('returns 403 when the actor is not the host', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    seedApproved(joinRequests);

    try {
      await useCase.execute({
        joinRequestId: 'jr_1',
        actorUserId: 'someone-else',
        reason: 'reason',
      });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      const e = err as AppError;
      expect(e.code).toBe('FORBIDDEN');
      expect(e.message).toMatch(/host/);
    }
  });

  it('throws ALREADY_REMOVED_BY_HOST on idempotent retry', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    const jr = seedApproved(joinRequests);
    jr.removeByHost({ by: 'host_1', hostUserId: 'host_1', reason: 'first time', now: NOW });
    jr.pullEvents();

    try {
      await useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'host_1', reason: 'second' });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      const e = err as AppError;
      expect(e.code).toBe('CONFLICT');
      expect(e.details).toEqual({ subcode: 'ALREADY_REMOVED_BY_HOST' });
    }
  });

  it('throws 409 with status name when JR is pending (non-approved state)', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    seedPending(joinRequests, 'jr_pending');

    try {
      await useCase.execute({
        joinRequestId: 'jr_pending',
        actorUserId: 'host_1',
        reason: 'reason',
      });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      const e = err as AppError;
      expect(e.code).toBe('CONFLICT');
      expect(e.message).toMatch(/pending/);
    }
  });

  it('throws 409 with status name when JR is rejected (non-approved state)', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    const jr = seedPending(joinRequests, 'jr_rejected');
    jr.reject({ by: 'host_1', reason: 'not a fit', now: NOW });
    jr.pullEvents();

    try {
      await useCase.execute({
        joinRequestId: 'jr_rejected',
        actorUserId: 'host_1',
        reason: 'reason',
      });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      const e = err as AppError;
      expect(e.code).toBe('CONFLICT');
      expect(e.message).toMatch(/rejected/);
    }
  });

  it('throws 409 with status name when JR is cancelled (non-approved state)', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    const jr = seedApproved(joinRequests);
    jr.cancelByRequester(NOW);
    jr.pullEvents();

    try {
      await useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'host_1', reason: 'reason' });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      const e = err as AppError;
      expect(e.code).toBe('CONFLICT');
      expect(e.message).toMatch(/cancelled/);
    }
  });

  it('throws 422 validation error when reason is empty', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    seedApproved(joinRequests);

    try {
      await useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'host_1', reason: '   ' });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      const e = err as AppError;
      expect(e.code).toBe('VALIDATION_ERROR');
      expect(e.message).toMatch(/reason/i);
    }
  });

  it('throws 422 validation error when reason exceeds 200 characters', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    seedApproved(joinRequests);

    const longReason = 'x'.repeat(201);
    try {
      await useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'host_1', reason: longReason });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      const e = err as AppError;
      expect(e.code).toBe('VALIDATION_ERROR');
    }
  });
});
