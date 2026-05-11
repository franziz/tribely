import { describe, expect, it } from 'vitest';
import { ONE_TIME_CODE_MAX_ATTEMPTS, OneTimeCodeLifecycle } from './one-time-code-lifecycle.js';

const create = (overrides: { now?: Date; expiresAt?: Date } = {}): OneTimeCodeLifecycle => {
  const issuedAt = overrides.now ?? new Date('2026-01-01T00:00:00Z');
  const expiresAt = overrides.expiresAt ?? new Date(issuedAt.getTime() + 24 * 60 * 60 * 1000);
  return OneTimeCodeLifecycle.create({ codeHash: 'h', issuedAt, expiresAt });
};

describe('OneTimeCodeLifecycle', () => {
  describe('create', () => {
    it('starts open, unconsumed, zero attempts, not invalidated', () => {
      const lc = create();
      expect(lc.isOpen(new Date('2026-01-01T01:00:00Z'))).toBe(true);
      expect(lc.attempts).toBe(0);
      expect(lc.invalidated).toBe(false);
      expect(lc.consumedAt).toBeNull();
    });
  });

  describe('rehydrate', () => {
    it('reconstructs full state from persistence', () => {
      const issuedAt = new Date('2026-01-01T00:00:00Z');
      const consumedAt = new Date('2026-01-01T01:00:00Z');
      const lc = OneTimeCodeLifecycle.rehydrate({
        codeHash: 'abc',
        issuedAt,
        expiresAt: new Date(issuedAt.getTime() + 60_000),
        consumedAt,
        attempts: 3,
        invalidated: false,
      });
      expect(lc.consumedAt).toEqual(consumedAt);
      expect(lc.attempts).toBe(3);
      expect(lc.codeHash).toBe('abc');
    });
  });

  describe('isOpen', () => {
    it('false once expired', () => {
      const lc = create({ expiresAt: new Date('2026-01-02T00:00:00Z') });
      expect(lc.isOpen(new Date('2026-01-01T23:59:59Z'))).toBe(true);
      expect(lc.isOpen(new Date('2026-01-02T00:00:00Z'))).toBe(false);
    });

    it('false once invalidated', () => {
      const lc = create();
      lc.invalidate(new Date('2026-01-01T01:00:00Z'));
      expect(lc.isOpen(new Date('2026-01-01T01:00:01Z'))).toBe(false);
    });

    it('false once consumed', () => {
      const lc = create();
      lc.consume(new Date('2026-01-01T01:00:00Z'));
      expect(lc.isOpen(new Date('2026-01-01T01:00:01Z'))).toBe(false);
    });
  });

  describe('consume', () => {
    it('marks consumedAt and reports first consumption', () => {
      const lc = create();
      const now = new Date('2026-01-01T01:00:00Z');
      const result = lc.consume(now);
      expect(result.wasAlreadyConsumed).toBe(false);
      expect(lc.consumedAt).toEqual(now);
      expect(lc.isConsumed()).toBe(true);
    });

    it('idempotent — second call signals already consumed', () => {
      const lc = create();
      const first = new Date('2026-01-01T01:00:00Z');
      const second = new Date('2026-01-01T02:00:00Z');
      lc.consume(first);
      const r = lc.consume(second);
      expect(r.wasAlreadyConsumed).toBe(true);
      expect(lc.consumedAt).toEqual(first);
    });

    it('throws if expired', () => {
      const lc = create({ expiresAt: new Date('2026-01-01T01:00:00Z') });
      expect(() => lc.consume(new Date('2026-01-01T01:00:01Z'))).toThrow(/expired/);
    });

    it('throws if invalidated', () => {
      const lc = create();
      lc.invalidate(new Date('2026-01-01T01:00:00Z'));
      expect(() => lc.consume(new Date('2026-01-01T01:00:01Z'))).toThrow(/invalidated/);
    });
  });

  describe('registerFailedAttempt', () => {
    it('increments attempts', () => {
      const lc = create();
      const r = lc.registerFailedAttempt(new Date('2026-01-01T01:00:00Z'));
      expect(r).toEqual({ recorded: true, becameInvalid: false });
      expect(lc.attempts).toBe(1);
      expect(lc.invalidated).toBe(false);
    });

    it('reports becameInvalid once cap is hit', () => {
      const lc = create();
      let last = { recorded: false, becameInvalid: false };
      for (let i = 0; i < ONE_TIME_CODE_MAX_ATTEMPTS; i += 1) {
        last = lc.registerFailedAttempt(new Date('2026-01-01T01:00:00Z'));
      }
      expect(last.becameInvalid).toBe(true);
      expect(lc.attempts).toBe(ONE_TIME_CODE_MAX_ATTEMPTS);
      expect(lc.invalidated).toBe(true);
    });

    it('no-op once invalidated', () => {
      const lc = create();
      lc.invalidate(new Date('2026-01-01T01:00:00Z'));
      const r = lc.registerFailedAttempt(new Date('2026-01-01T02:00:00Z'));
      expect(r).toEqual({ recorded: false, becameInvalid: false });
      expect(lc.attempts).toBe(0);
    });

    it('no-op once consumed', () => {
      const lc = create();
      lc.consume(new Date('2026-01-01T01:00:00Z'));
      const r = lc.registerFailedAttempt(new Date('2026-01-01T02:00:00Z'));
      expect(r).toEqual({ recorded: false, becameInvalid: false });
      expect(lc.attempts).toBe(0);
    });
  });

  describe('invalidate', () => {
    it('marks invalidated and reports first invalidation', () => {
      const lc = create();
      const r = lc.invalidate(new Date('2026-01-01T01:00:00Z'));
      expect(r.wasAlreadyInvalidated).toBe(false);
      expect(lc.invalidated).toBe(true);
    });

    it('idempotent — second call signals already invalidated', () => {
      const lc = create();
      lc.invalidate(new Date('2026-01-01T01:00:00Z'));
      const r = lc.invalidate(new Date('2026-01-01T02:00:00Z'));
      expect(r.wasAlreadyInvalidated).toBe(true);
    });
  });
});
