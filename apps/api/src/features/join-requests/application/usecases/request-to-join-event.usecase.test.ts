import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Event, type ApprovalMode } from '@/features/events/domain/entities/event.js';
import { Capacity } from '@/features/events/domain/value-objects/capacity.js';
import { EventCategory } from '@/features/events/domain/value-objects/event-category.js';
import { Venue } from '@/features/events/domain/value-objects/venue.js';
import { JoinRequest } from '../../domain/entities/join-request.js';
import { JOIN_REQUEST_APPROVED } from '../../domain/events/approved.event.js';
import { JOIN_REQUEST_REQUESTED } from '../../domain/events/requested.event.js';
import { RequestToJoinEventUseCase } from './request-to-join-event.usecase.js';
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

interface SeedOpts {
  id?: string;
  hostUserId?: string;
  approvalMode?: ApprovalMode;
  capacity?: number;
}

const seedPublishedEvent = (repo: FakeEventRepository, opts: SeedOpts = {}): Event => {
  const event = Event.create({
    id: opts.id ?? 'evt_1',
    hostUserId: opts.hostUserId ?? 'host_1',
    title: 'Hawker tour',
    description: null,
    venue: Venue.create({
      address: '18 Raffles Quay',
      city: 'Singapore',
      latitude: 1.2806,
      longitude: 103.8504,
    }),
    startsAt: STARTS,
    endsAt: ENDS,
    capacity: Capacity.create(opts.capacity ?? 6),
    category: EventCategory.create('food'),
    costSplit: 'own',
    approvalMode: opts.approvalMode ?? 'manual',
    now: NOW,
  });
  event.publish(NOW);
  event.pullEvents();
  repo.put(event);
  return event;
};

const buildSut = () => {
  const events = new FakeEventRepository();
  const joinRequests = new FakeJoinRequestRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new RequestToJoinEventUseCase(uow, joinRequests, events, publisher, clock);
  return { events, joinRequests, publisher, clock, useCase };
};

describe('RequestToJoinEventUseCase', () => {
  describe('manual approval', () => {
    it('creates a pending request and emits joinRequests.requested', async () => {
      const { events, joinRequests, publisher, useCase } = buildSut();
      seedPublishedEvent(events);

      const jr = await useCase.execute({ eventId: 'evt_1', requesterUserId: 'requester_1' });

      expect(jr.status).toBe('pending');
      expect(jr.eventId).toBe('evt_1');
      expect(jr.requesterUserId).toBe('requester_1');
      expect(joinRequests.all()).toHaveLength(1);
      expect(publisher.published.map((e) => e.type)).toEqual([JOIN_REQUEST_REQUESTED]);
    });
  });

  describe('auto approval', () => {
    it('creates an approved request and emits both requested + approved', async () => {
      const { events, publisher, useCase } = buildSut();
      seedPublishedEvent(events, { approvalMode: 'auto', hostUserId: 'host_42' });

      const jr = await useCase.execute({ eventId: 'evt_1', requesterUserId: 'requester_1' });

      expect(jr.status).toBe('approved');
      expect(jr.decidedByUserId).toBe('host_42');
      expect(publisher.published.map((e) => e.type)).toEqual([
        JOIN_REQUEST_REQUESTED,
        JOIN_REQUEST_APPROVED,
      ]);
    });

    it('rejects with CAPACITY_FULL when approved count is at capacity - 1', async () => {
      const { events, joinRequests, useCase } = buildSut();
      // capacity=3 means 2 seats for requesters; pre-seed 2 approved → full.
      seedPublishedEvent(events, { approvalMode: 'auto', capacity: 3 });
      for (const userId of ['u_a', 'u_b']) {
        joinRequests.put(
          JoinRequest.request({
            id: `jr_seed_${userId}`,
            eventId: 'evt_1',
            requesterUserId: userId,
            now: NOW,
            autoApprove: true,
            hostUserId: 'host_1',
            eventSnapshot: snapshotFor(STARTS, ENDS, 'host_1'),
          }),
        );
      }

      try {
        await useCase.execute({ eventId: 'evt_1', requesterUserId: 'requester_1' });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('CONFLICT');
        expect(e.details).toEqual({ subcode: 'CAPACITY_FULL' });
      }
    });
  });

  describe('validation', () => {
    it('returns 404 when the event does not exist', async () => {
      const { useCase } = buildSut();
      await expect(
        useCase.execute({ eventId: 'missing', requesterUserId: 'requester_1' }),
      ).rejects.toThrowError(AppError);
    });

    it('throws CANNOT_JOIN_OWN_EVENT when the actor is the host', async () => {
      const { events, useCase } = buildSut();
      seedPublishedEvent(events, { hostUserId: 'host_1' });

      try {
        await useCase.execute({ eventId: 'evt_1', requesterUserId: 'host_1' });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('CONFLICT');
        expect(e.details).toEqual({ subcode: 'CANNOT_JOIN_OWN_EVENT' });
      }
    });

    it('throws ACTIVE_REQUEST_EXISTS when a pending request is already present', async () => {
      const { events, joinRequests, useCase } = buildSut();
      seedPublishedEvent(events);
      joinRequests.put(
        JoinRequest.request({
          id: 'jr_existing',
          eventId: 'evt_1',
          requesterUserId: 'requester_1',
          now: NOW,
          autoApprove: false,
          hostUserId: 'host_1',
          eventSnapshot: snapshotFor(STARTS, ENDS, 'host_1'),
        }),
      );

      try {
        await useCase.execute({ eventId: 'evt_1', requesterUserId: 'requester_1' });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('CONFLICT');
        expect(e.details).toEqual({ subcode: 'ACTIVE_REQUEST_EXISTS' });
      }
    });

    it('throws EVENT_CANCELLED when the event is cancelled', async () => {
      const { events, useCase } = buildSut();
      const event = seedPublishedEvent(events);
      event.cancel('weather', new Date(NOW.getTime() + 1000));
      event.pullEvents();

      try {
        await useCase.execute({ eventId: 'evt_1', requesterUserId: 'requester_1' });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('CONFLICT');
        expect(e.details).toEqual({ subcode: 'EVENT_CANCELLED' });
      }
    });

    it('throws EVENT_ALREADY_STARTED when endsAt is in the past relative to clock', async () => {
      const { events, clock, useCase } = buildSut();
      seedPublishedEvent(events);
      // Advance the clock to AFTER endsAt.
      clock.set(new Date(ENDS.getTime() + 1000));

      try {
        await useCase.execute({ eventId: 'evt_1', requesterUserId: 'requester_1' });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('CONFLICT');
        expect(e.details).toEqual({ subcode: 'EVENT_ALREADY_STARTED' });
      }
    });
  });
});

const snapshotFor = (startsAt: Date, endsAt: Date, hostUserId: string) => ({
  startsAt,
  endsAt,
  venue: { address: '18 Raffles Quay', city: 'Singapore', latitude: 1.2806, longitude: 103.8504 },
  hostUserId,
});
