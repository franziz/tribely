import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Event } from '@/features/events/domain/entities/event.js';
import { Capacity } from '@/features/events/domain/value-objects/capacity.js';
import { EventCategory } from '@/features/events/domain/value-objects/event-category.js';
import { Venue } from '@/features/events/domain/value-objects/venue.js';
import { JoinRequest } from '../../domain/entities/join-request.js';
import { JOIN_REQUEST_REJECTED } from '../../domain/events/rejected.event.js';
import { RejectJoinRequestUseCase } from './reject-join-request.usecase.js';
import {
  FakeEventPublisher,
  FakeEventRepository,
  FakeJoinRequestRepository,
  FakeUnitOfWork,
  FixedClock,
} from './__test__/fakes.js';

const NOW = new Date('2026-05-11T00:00:00Z');
const STARTS = new Date(NOW.getTime() + 7 * 24 * 60 * 60 * 1000);
const ENDS = new Date(STARTS.getTime() + 3 * 60 * 60 * 1000);
const SNAPSHOT = {
  startsAt: STARTS,
  endsAt: ENDS,
  venue: { address: '18 Raffles Quay', city: 'Singapore', latitude: 1.2806, longitude: 103.8504 },
  hostUserId: 'host_1',
};

const seedEvent = (repo: FakeEventRepository) => {
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
    costSplit: 'own',
    approvalMode: 'manual',
    now: NOW,
  });
  event.publish(NOW);
  event.pullEvents();
  repo.put(event);
};

const seedPending = (repo: FakeJoinRequestRepository): JoinRequest => {
  const jr = JoinRequest.request({
    id: 'jr_1',
    eventId: 'evt_1',
    requesterUserId: 'requester_1',
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
  const useCase = new RejectJoinRequestUseCase(uow, joinRequests, events, publisher, clock);
  return { events, joinRequests, publisher, useCase };
};

describe('RejectJoinRequestUseCase', () => {
  it('rejects a pending request and emits joinRequests.rejected with trimmed reason', async () => {
    const { events, joinRequests, publisher, useCase } = buildSut();
    seedEvent(events);
    seedPending(joinRequests);

    const jr = await useCase.execute({
      joinRequestId: 'jr_1',
      actorUserId: 'host_1',
      reason: '  not a fit  ',
    });

    expect(jr.status).toBe('rejected');
    expect(jr.decisionReason).toBe('not a fit');
    expect(publisher.published).toHaveLength(1);
    const ev = publisher.published[0];
    expect(ev?.type).toBe(JOIN_REQUEST_REJECTED);
    expect(ev?.payload).toMatchObject({
      id: 'jr_1',
      rejectedByUserId: 'host_1',
      reason: 'not a fit',
    });
  });

  it('returns 404 when the join request does not exist', async () => {
    const { events, useCase } = buildSut();
    seedEvent(events);
    await expect(
      useCase.execute({ joinRequestId: 'missing', actorUserId: 'host_1', reason: 'no' }),
    ).rejects.toThrowError(AppError);
  });

  it('forbids rejection by anyone other than the host', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    seedPending(joinRequests);
    await expect(
      useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'someone-else', reason: 'no' }),
    ).rejects.toThrowError(/host/);
  });

  it('propagates validation error when reason is empty / whitespace', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    seedPending(joinRequests);
    await expect(
      useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'host_1', reason: '   ' }),
    ).rejects.toThrowError(/reason/);
  });

  it('propagates ALREADY_REJECTED from the aggregate on re-reject', async () => {
    const { events, joinRequests, useCase } = buildSut();
    seedEvent(events);
    const jr = seedPending(joinRequests);
    jr.reject({ by: 'host_1', reason: 'full', now: NOW });
    jr.pullEvents();

    try {
      await useCase.execute({
        joinRequestId: 'jr_1',
        actorUserId: 'host_1',
        reason: 'still full',
      });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      const e = err as AppError;
      expect(e.code).toBe('CONFLICT');
      expect(e.details).toEqual({ subcode: 'ALREADY_REJECTED' });
    }
  });
});
