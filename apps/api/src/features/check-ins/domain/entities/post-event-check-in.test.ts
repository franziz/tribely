import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { CHECK_IN_ACKNOWLEDGED } from '../events/check-in-acknowledged.event.js';
import { CHECK_IN_CREATED } from '../events/check-in-created.event.js';
import { CHECK_IN_FLAGGED } from '../events/check-in-flagged.event.js';
import { PostEventCheckIn } from './post-event-check-in.js';

const NOW = new Date('2026-06-02T12:00:00Z');

const created = (
  overrides: Partial<Parameters<typeof PostEventCheckIn.create>[0]> = {},
): PostEventCheckIn =>
  PostEventCheckIn.create({
    id: 'chk_1',
    userId: 'user_1',
    eventId: 'evt_1',
    hostUserId: 'host_1',
    now: NOW,
    ...overrides,
  });

describe('PostEventCheckIn', () => {
  describe('create', () => {
    it('initialises with status=pending and null timestamps', () => {
      const chk = created();
      expect(chk.id).toBe('chk_1');
      expect(chk.userId).toBe('user_1');
      expect(chk.eventId).toBe('evt_1');
      expect(chk.hostUserId).toBe('host_1');
      expect(chk.status).toBe('pending');
      expect(chk.createdAt).toEqual(NOW);
      expect(chk.acknowledgedAt).toBeNull();
      expect(chk.flaggedAt).toBeNull();
      expect(chk.reportBody).toBeNull();
      expect(chk.resolvedAt).toBeNull();
    });

    it('records checkIns.checkInCreated with correct payload', () => {
      const chk = created();
      const events = chk.pullEvents();
      expect(events).toHaveLength(1);
      const ev = events[0];
      expect(ev?.type).toBe(CHECK_IN_CREATED);
      expect(ev?.aggregateType).toBe('PostEventCheckIn');
      expect(ev?.aggregateId).toBe('chk_1');
      expect(ev?.payload).toMatchObject({
        checkInId: 'chk_1',
        userId: 'user_1',
        eventId: 'evt_1',
        hostUserId: 'host_1',
        createdAt: NOW.toISOString(),
      });
    });
  });

  describe('acknowledge', () => {
    it('transitions pending → ok, sets acknowledgedAt, records checkIns.checkInAcknowledged', () => {
      const chk = created();
      chk.pullEvents();
      const at = new Date(NOW.getTime() + 1000);
      chk.acknowledge({ now: at });

      expect(chk.status).toBe('ok');
      expect(chk.acknowledgedAt).toEqual(at);
      expect(chk.flaggedAt).toBeNull();
      expect(chk.reportBody).toBeNull();

      const events = chk.pullEvents();
      expect(events).toHaveLength(1);
      const ev = events[0];
      expect(ev?.type).toBe(CHECK_IN_ACKNOWLEDGED);
      expect(ev?.aggregateType).toBe('PostEventCheckIn');
      expect(ev?.aggregateId).toBe('chk_1');
      expect(ev?.payload).toMatchObject({
        checkInId: 'chk_1',
        userId: 'user_1',
        eventId: 'evt_1',
        acknowledgedAt: at.toISOString(),
      });
    });

    it('throws CONFLICT when status is already ok', () => {
      const chk = created();
      chk.acknowledge({ now: NOW });
      expect(() => {
        chk.acknowledge({ now: NOW });
      }).toThrow(AppError);
      try {
        chk.acknowledge({ now: NOW });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        expect((err as AppError).code).toBe('CONFLICT');
      }
    });

    it('throws CONFLICT when status is flagged', () => {
      const chk = created();
      chk.flag({ reportBody: 'Bad experience', now: NOW });
      expect(() => {
        chk.acknowledge({ now: NOW });
      }).toThrow(AppError);
      try {
        chk.acknowledge({ now: NOW });
        expect.fail('expected throw');
      } catch (err) {
        expect((err as AppError).code).toBe('CONFLICT');
      }
    });
  });

  describe('flag', () => {
    it('transitions pending → flagged, sets flaggedAt + reportBody, records checkIns.checkInFlagged', () => {
      const chk = created();
      chk.pullEvents();
      const at = new Date(NOW.getTime() + 2000);
      chk.flag({ reportBody: '  Host was rude.  ', now: at });

      expect(chk.status).toBe('flagged');
      expect(chk.flaggedAt).toEqual(at);
      expect(chk.reportBody).toBe('Host was rude.'); // trimmed
      expect(chk.acknowledgedAt).toBeNull();

      const events = chk.pullEvents();
      expect(events).toHaveLength(1);
      const ev = events[0];
      expect(ev?.type).toBe(CHECK_IN_FLAGGED);
      expect(ev?.aggregateType).toBe('PostEventCheckIn');
      expect(ev?.aggregateId).toBe('chk_1');
      expect(ev?.payload).toMatchObject({
        checkInId: 'chk_1',
        userId: 'user_1',
        eventId: 'evt_1',
        hostUserId: 'host_1',
        flaggedAt: at.toISOString(),
        reportBody: 'Host was rude.',
      });
    });

    it('throws UNPROCESSABLE with subcode REPORT_EMPTY when reportBody is empty', () => {
      const chk = created();
      try {
        chk.flag({ reportBody: '', now: NOW });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('UNPROCESSABLE');
        expect(e.details).toEqual({ subcode: 'REPORT_EMPTY' });
      }
    });

    it('throws UNPROCESSABLE with subcode REPORT_EMPTY when reportBody is whitespace-only', () => {
      const chk = created();
      try {
        chk.flag({ reportBody: '   ', now: NOW });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('UNPROCESSABLE');
        expect(e.details).toEqual({ subcode: 'REPORT_EMPTY' });
      }
    });

    it('throws UNPROCESSABLE with subcode REPORT_TOO_LONG when reportBody exceeds 2000 chars', () => {
      const chk = created();
      try {
        chk.flag({ reportBody: 'x'.repeat(2001), now: NOW });
        expect.fail('expected throw');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        const e = err as AppError;
        expect(e.code).toBe('UNPROCESSABLE');
        expect(e.details).toEqual({ subcode: 'REPORT_TOO_LONG' });
      }
    });

    it('accepts reportBody of exactly 2000 chars', () => {
      const chk = created();
      expect(() => {
        chk.flag({ reportBody: 'x'.repeat(2000), now: NOW });
      }).not.toThrow();
      expect(chk.status).toBe('flagged');
    });

    it('throws CONFLICT when status is ok', () => {
      const chk = created();
      chk.acknowledge({ now: NOW });
      try {
        chk.flag({ reportBody: 'Something', now: NOW });
        expect.fail('expected throw');
      } catch (err) {
        expect((err as AppError).code).toBe('CONFLICT');
      }
    });

    it('throws CONFLICT when status is already flagged', () => {
      const chk = created();
      chk.flag({ reportBody: 'First report', now: NOW });
      try {
        chk.flag({ reportBody: 'Second report', now: NOW });
        expect.fail('expected throw');
      } catch (err) {
        expect((err as AppError).code).toBe('CONFLICT');
      }
    });
  });

  describe('rehydrate', () => {
    it('produces correct state and records no events', () => {
      const chk = PostEventCheckIn.rehydrate({
        id: 'chk_2',
        userId: 'user_2',
        eventId: 'evt_2',
        hostUserId: 'host_2',
        status: 'flagged',
        createdAt: NOW,
        acknowledgedAt: null,
        flaggedAt: new Date(NOW.getTime() + 5000),
        reportBody: 'Unsafe environment',
        resolvedAt: null,
      });
      expect(chk.id).toBe('chk_2');
      expect(chk.status).toBe('flagged');
      expect(chk.reportBody).toBe('Unsafe environment');
      expect(chk.pullEvents()).toHaveLength(0);
    });
  });
});
