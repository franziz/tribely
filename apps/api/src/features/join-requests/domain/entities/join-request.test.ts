import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { JOIN_REQUEST_APPROVED } from '../events/approved.event.js';
import { JOIN_REQUEST_CANCELLED_BY_REQUESTER } from '../events/cancelled-by-requester.event.js';
import { JOIN_REQUEST_REJECTED } from '../events/rejected.event.js';
import { JOIN_REQUEST_REMOVED_BY_HOST } from '../events/removed-by-host.event.js';
import { JOIN_REQUEST_REQUESTED } from '../events/requested.event.js';
import { JoinRequest, type JoinRequestEventSnapshot } from './join-request.js';

const NOW = new Date('2026-05-11T00:00:00Z');
const STARTS = new Date('2026-06-01T18:00:00Z');
const ENDS = new Date('2026-06-01T22:00:00Z');

const SNAPSHOT: JoinRequestEventSnapshot = {
  startsAt: STARTS,
  endsAt: ENDS,
  venue: {
    address: '18 Raffles Quay, Singapore',
    city: 'Singapore',
    latitude: 1.2806,
    longitude: 103.8504,
  },
  hostUserId: 'host_1',
};

const requested = (
  overrides: Partial<Parameters<typeof JoinRequest.request>[0]> = {},
): JoinRequest =>
  JoinRequest.request({
    id: 'jr_1',
    eventId: 'evt_1',
    requesterUserId: 'requester_1',
    now: NOW,
    autoApprove: false,
    hostUserId: 'host_1',
    eventSnapshot: SNAPSHOT,
    ...overrides,
  });

describe('JoinRequest', () => {
  describe('request', () => {
    it('starts as pending with no decision metadata', () => {
      const jr = requested();
      expect(jr.id).toBe('jr_1');
      expect(jr.eventId).toBe('evt_1');
      expect(jr.requesterUserId).toBe('requester_1');
      expect(jr.requestedAt).toEqual(NOW);
      expect(jr.status).toBe('pending');
      expect(jr.decidedAt).toBeNull();
      expect(jr.decidedByUserId).toBeNull();
      expect(jr.decisionReason).toBeNull();
    });

    it('records joinRequests.requested with the event snapshot', () => {
      const jr = requested();
      const events = jr.pullEvents();
      expect(events).toHaveLength(1);
      const ev = events[0];
      expect(ev?.type).toBe(JOIN_REQUEST_REQUESTED);
      expect(ev?.aggregateType).toBe('JoinRequest');
      expect(ev?.aggregateId).toBe('jr_1');
      expect(ev?.payload).toMatchObject({
        id: 'jr_1',
        eventId: 'evt_1',
        requesterUserId: 'requester_1',
        requestedAt: NOW.toISOString(),
        eventStartsAt: STARTS.toISOString(),
        eventEndsAt: ENDS.toISOString(),
      });
    });

    describe('with autoApprove=true', () => {
      it('lands in approved status with the host as decider', () => {
        const jr = requested({ autoApprove: true });
        expect(jr.status).toBe('approved');
        expect(jr.decidedAt).toEqual(NOW);
        expect(jr.decidedByUserId).toBe('host_1');
        expect(jr.decisionReason).toBeNull();
      });

      it('records BOTH requested AND approved events on the same aggregate', () => {
        const jr = requested({ autoApprove: true });
        const events = jr.pullEvents();
        expect(events).toHaveLength(2);
        expect(events[0]?.type).toBe(JOIN_REQUEST_REQUESTED);
        expect(events[1]?.type).toBe(JOIN_REQUEST_APPROVED);
        expect(events[1]?.payload).toMatchObject({
          id: 'jr_1',
          eventId: 'evt_1',
          requesterUserId: 'requester_1',
          approvedByUserId: 'host_1',
          hostUserId: 'host_1',
          eventVenue: {
            address: SNAPSHOT.venue.address,
            city: SNAPSHOT.venue.city,
            latitude: SNAPSHOT.venue.latitude,
            longitude: SNAPSHOT.venue.longitude,
          },
        });
      });
    });
  });

  describe('approve', () => {
    it('transitions pending → approved and records joinRequests.approved', () => {
      const jr = requested();
      jr.pullEvents();
      const at = new Date(NOW.getTime() + 1000);
      jr.approve({ by: 'host_1', now: at, eventSnapshot: SNAPSHOT });
      expect(jr.status).toBe('approved');
      expect(jr.decidedAt).toEqual(at);
      expect(jr.decidedByUserId).toBe('host_1');
      expect(jr.decisionReason).toBeNull();
      const events = jr.pullEvents();
      expect(events).toHaveLength(1);
      const ev = events[0];
      expect(ev?.type).toBe(JOIN_REQUEST_APPROVED);
      expect(ev?.payload).toMatchObject({
        id: 'jr_1',
        eventId: 'evt_1',
        requesterUserId: 'requester_1',
        approvedByUserId: 'host_1',
        hostUserId: 'host_1',
        approvedAt: at.toISOString(),
        eventStartsAt: STARTS.toISOString(),
        eventEndsAt: ENDS.toISOString(),
      });
    });

    it('throws CONFLICT with subcode ALREADY_APPROVED when already approved', () => {
      const jr = requested();
      jr.approve({ by: 'host_1', now: NOW, eventSnapshot: SNAPSHOT });
      try {
        jr.approve({ by: 'host_1', now: NOW, eventSnapshot: SNAPSHOT });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('CONFLICT');
        expect(e.details).toEqual({ subcode: 'ALREADY_APPROVED' });
      }
    });

    it('throws CONFLICT when rejected (no subcode required)', () => {
      const jr = requested();
      jr.reject({ by: 'host_1', reason: 'full', now: NOW });
      expect(() => {
        jr.approve({ by: 'host_1', now: NOW, eventSnapshot: SNAPSHOT });
      }).toThrowError(/Cannot approve/);
    });

    it('throws CONFLICT when cancelled', () => {
      const jr = requested();
      jr.cancelByRequester(NOW);
      expect(() => {
        jr.approve({ by: 'host_1', now: NOW, eventSnapshot: SNAPSHOT });
      }).toThrowError(/Cannot approve/);
    });
  });

  describe('reject', () => {
    it('transitions pending → rejected and records joinRequests.rejected', () => {
      const jr = requested();
      jr.pullEvents();
      const at = new Date(NOW.getTime() + 1000);
      jr.reject({ by: 'host_1', reason: '  not a fit  ', now: at });
      expect(jr.status).toBe('rejected');
      expect(jr.decidedAt).toEqual(at);
      expect(jr.decidedByUserId).toBe('host_1');
      expect(jr.decisionReason).toBe('not a fit');
      const events = jr.pullEvents();
      expect(events).toHaveLength(1);
      const ev = events[0];
      expect(ev?.type).toBe(JOIN_REQUEST_REJECTED);
      expect(ev?.payload).toMatchObject({
        id: 'jr_1',
        eventId: 'evt_1',
        requesterUserId: 'requester_1',
        rejectedByUserId: 'host_1',
        reason: 'not a fit',
        rejectedAt: at.toISOString(),
      });
    });

    it('rejects empty / whitespace reason', () => {
      const jr = requested();
      expect(() => {
        jr.reject({ by: 'host_1', reason: '', now: NOW });
      }).toThrowError(/reason/);
      expect(() => {
        jr.reject({ by: 'host_1', reason: '   ', now: NOW });
      }).toThrowError(/reason/);
    });

    it('rejects a reason longer than 500 chars', () => {
      const jr = requested();
      expect(() => {
        jr.reject({ by: 'host_1', reason: 'x'.repeat(501), now: NOW });
      }).toThrowError(/500/);
    });

    it('throws CONFLICT with subcode ALREADY_REJECTED when already rejected', () => {
      const jr = requested();
      jr.reject({ by: 'host_1', reason: 'full', now: NOW });
      try {
        jr.reject({ by: 'host_1', reason: 'still full', now: NOW });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('CONFLICT');
        expect(e.details).toEqual({ subcode: 'ALREADY_REJECTED' });
      }
    });

    it('throws CONFLICT when approved', () => {
      const jr = requested();
      jr.approve({ by: 'host_1', now: NOW, eventSnapshot: SNAPSHOT });
      expect(() => {
        jr.reject({ by: 'host_1', reason: 'changed my mind', now: NOW });
      }).toThrowError(/Cannot reject/);
    });

    it('throws CONFLICT when cancelled', () => {
      const jr = requested();
      jr.cancelByRequester(NOW);
      expect(() => {
        jr.reject({ by: 'host_1', reason: 'too late', now: NOW });
      }).toThrowError(/Cannot reject/);
    });
  });

  describe('cancelByRequester', () => {
    it('transitions pending → cancelled and records previousStatus=pending', () => {
      const jr = requested();
      jr.pullEvents();
      const at = new Date(NOW.getTime() + 1000);
      jr.cancelByRequester(at);
      expect(jr.status).toBe('cancelled');
      expect(jr.decidedAt).toEqual(at);
      expect(jr.decidedByUserId).toBeNull();
      expect(jr.decisionReason).toBeNull();
      const events = jr.pullEvents();
      expect(events).toHaveLength(1);
      const ev = events[0];
      expect(ev?.type).toBe(JOIN_REQUEST_CANCELLED_BY_REQUESTER);
      expect(ev?.payload).toMatchObject({
        id: 'jr_1',
        eventId: 'evt_1',
        requesterUserId: 'requester_1',
        previousStatus: 'pending',
        cancelledAt: at.toISOString(),
      });
    });

    it('transitions approved → cancelled and records previousStatus=approved', () => {
      const jr = requested();
      jr.approve({ by: 'host_1', now: NOW, eventSnapshot: SNAPSHOT });
      jr.pullEvents();
      const at = new Date(NOW.getTime() + 1000);
      jr.cancelByRequester(at);
      expect(jr.status).toBe('cancelled');
      const events = jr.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.payload).toMatchObject({ previousStatus: 'approved' });
    });

    it('throws CONFLICT with subcode ALREADY_CANCELLED when already cancelled', () => {
      const jr = requested();
      jr.cancelByRequester(NOW);
      try {
        jr.cancelByRequester(NOW);
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('CONFLICT');
        expect(e.details).toEqual({ subcode: 'ALREADY_CANCELLED' });
      }
    });

    it('throws CONFLICT when rejected', () => {
      const jr = requested();
      jr.reject({ by: 'host_1', reason: 'full', now: NOW });
      expect(() => {
        jr.cancelByRequester(NOW);
      }).toThrowError(/Cannot cancel/);
    });
  });

  describe('removeByHost', () => {
    it('transitions approved → removed_by_host and records joinRequests.removedByHost', () => {
      const jr = requested();
      jr.approve({ by: 'host_1', now: NOW, eventSnapshot: SNAPSHOT });
      jr.pullEvents();
      const at = new Date(NOW.getTime() + 1000);
      jr.removeByHost({
        by: 'host_1',
        reason: '  behaviour issue  ',
        now: at,
        hostUserId: 'host_1',
      });
      expect(jr.status).toBe('removed_by_host');
      expect(jr.decidedAt).toEqual(at);
      expect(jr.decidedByUserId).toBe('host_1');
      expect(jr.decisionReason).toBe('behaviour issue');
      const events = jr.pullEvents();
      expect(events).toHaveLength(1);
      const ev = events[0];
      expect(ev?.type).toBe(JOIN_REQUEST_REMOVED_BY_HOST);
      expect(ev?.payload).toMatchObject({
        id: 'jr_1',
        eventId: 'evt_1',
        requesterUserId: 'requester_1',
        removedByUserId: 'host_1',
        hostUserId: 'host_1',
        reason: 'behaviour issue',
        removedAt: at.toISOString(),
      });
    });

    it('rejects empty / whitespace reason', () => {
      const jr = requested();
      jr.approve({ by: 'host_1', now: NOW, eventSnapshot: SNAPSHOT });
      expect(() => {
        jr.removeByHost({ by: 'host_1', reason: '', now: NOW, hostUserId: 'host_1' });
      }).toThrowError(/reason/);
      expect(() => {
        jr.removeByHost({ by: 'host_1', reason: '   ', now: NOW, hostUserId: 'host_1' });
      }).toThrowError(/reason/);
    });

    it('rejects a reason longer than 200 chars', () => {
      const jr = requested();
      jr.approve({ by: 'host_1', now: NOW, eventSnapshot: SNAPSHOT });
      expect(() => {
        jr.removeByHost({ by: 'host_1', reason: 'x'.repeat(201), now: NOW, hostUserId: 'host_1' });
      }).toThrowError(/200/);
    });

    it('throws CONFLICT with subcode ALREADY_REMOVED_BY_HOST when already removed', () => {
      const jr = requested();
      jr.approve({ by: 'host_1', now: NOW, eventSnapshot: SNAPSHOT });
      jr.removeByHost({ by: 'host_1', reason: 'bad vibe', now: NOW, hostUserId: 'host_1' });
      try {
        jr.removeByHost({ by: 'host_1', reason: 'still bad', now: NOW, hostUserId: 'host_1' });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('CONFLICT');
        expect(e.details).toEqual({ subcode: 'ALREADY_REMOVED_BY_HOST' });
      }
    });

    it('throws CONFLICT when pending', () => {
      const jr = requested();
      expect(() => {
        jr.removeByHost({ by: 'host_1', reason: 'wrong', now: NOW, hostUserId: 'host_1' });
      }).toThrowError(/Cannot remove from status: pending/);
    });

    it('throws CONFLICT when rejected', () => {
      const jr = requested();
      jr.reject({ by: 'host_1', reason: 'full', now: NOW });
      expect(() => {
        jr.removeByHost({ by: 'host_1', reason: 'wrong', now: NOW, hostUserId: 'host_1' });
      }).toThrowError(/Cannot remove from status: rejected/);
    });

    it('throws CONFLICT when cancelled', () => {
      const jr = requested();
      jr.cancelByRequester(NOW);
      expect(() => {
        jr.removeByHost({ by: 'host_1', reason: 'wrong', now: NOW, hostUserId: 'host_1' });
      }).toThrowError(/Cannot remove from status: cancelled/);
    });
  });

  describe('rehydrate', () => {
    it('produces correct state and records no events', () => {
      const jr = JoinRequest.rehydrate({
        id: 'jr_1',
        eventId: 'evt_1',
        requesterUserId: 'requester_1',
        requestedAt: NOW,
        status: 'approved',
        decidedAt: new Date(NOW.getTime() + 1000),
        decidedByUserId: 'host_1',
        decisionReason: null,
      });
      expect(jr.status).toBe('approved');
      expect(jr.decidedByUserId).toBe('host_1');
      expect(jr.pullEvents()).toHaveLength(0);
    });
  });
});
