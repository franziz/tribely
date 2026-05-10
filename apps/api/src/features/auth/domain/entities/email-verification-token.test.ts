import { describe, expect, it } from 'vitest';
import { EMAIL_VERIFICATION_CONSUMED } from '../events/email-verification-consumed.event.js';
import { EMAIL_VERIFICATION_INVALIDATED } from '../events/email-verification-invalidated.event.js';
import { EMAIL_VERIFICATION_ISSUED } from '../events/email-verification-issued.event.js';
import {
  EMAIL_VERIFICATION_MAX_ATTEMPTS,
  EmailVerificationToken,
} from './email-verification-token.js';

const issue = (overrides: { now?: Date; expiresAt?: Date } = {}): EmailVerificationToken => {
  const now = overrides.now ?? new Date('2026-01-01T00:00:00Z');
  const expiresAt = overrides.expiresAt ?? new Date(now.getTime() + 48 * 60 * 60 * 1000);
  return EmailVerificationToken.issue({
    id: 'tok_1',
    userId: 'user_1',
    codeHash: 'hash',
    expiresAt,
    now,
  });
};

describe('EmailVerificationToken', () => {
  describe('issue', () => {
    it('records issued event', () => {
      const token = issue();
      const events = token.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(EMAIL_VERIFICATION_ISSUED);
      expect(events[0]?.payload).toMatchObject({ tokenId: 'tok_1', userId: 'user_1' });
    });

    it('starts open, unconsumed, zero attempts, not invalidated', () => {
      const token = issue();
      token.pullEvents();
      expect(token.isOpen(new Date('2026-01-01T01:00:00Z'))).toBe(true);
      expect(token.attempts).toBe(0);
      expect(token.invalidated).toBe(false);
      expect(token.consumedAt).toBeNull();
    });
  });

  describe('isOpen', () => {
    it('false once expired', () => {
      const token = issue({ expiresAt: new Date('2026-01-02T00:00:00Z') });
      token.pullEvents();
      expect(token.isOpen(new Date('2026-01-02T00:00:00Z'))).toBe(false);
      expect(token.isOpen(new Date('2026-01-01T23:59:59Z'))).toBe(true);
    });
  });

  describe('consume', () => {
    it('marks consumed + records consumed event', () => {
      const token = issue();
      token.pullEvents();
      const now = new Date('2026-01-01T01:00:00Z');

      token.consume(now);

      expect(token.consumedAt).toEqual(now);
      expect(token.isConsumed()).toBe(true);
      const events = token.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(EMAIL_VERIFICATION_CONSUMED);
    });

    it('idempotent — second call is a no-op', () => {
      const token = issue();
      token.pullEvents();
      const first = new Date('2026-01-01T01:00:00Z');
      const second = new Date('2026-01-01T02:00:00Z');

      token.consume(first);
      token.pullEvents();
      token.consume(second);

      expect(token.consumedAt).toEqual(first);
      expect(token.pullEvents()).toHaveLength(0);
    });

    it('throws if expired', () => {
      const token = issue({ expiresAt: new Date('2026-01-01T01:00:00Z') });
      token.pullEvents();
      expect(() => {
        token.consume(new Date('2026-01-01T01:00:01Z'));
      }).toThrow(/expired/);
    });

    it('throws if invalidated', () => {
      const token = issue();
      token.pullEvents();
      token.invalidate('replaced', new Date('2026-01-01T01:00:00Z'));
      token.pullEvents();
      expect(() => {
        token.consume(new Date('2026-01-01T01:01:00Z'));
      }).toThrow(/invalidated/);
    });
  });

  describe('registerFailedAttempt', () => {
    it('increments attempts', () => {
      const token = issue();
      token.pullEvents();
      const now = new Date('2026-01-01T01:00:00Z');
      token.registerFailedAttempt(now);
      expect(token.attempts).toBe(1);
      expect(token.invalidated).toBe(false);
    });

    it('auto-invalidates once attempts hits the cap', () => {
      const token = issue();
      token.pullEvents();
      const now = new Date('2026-01-01T01:00:00Z');

      for (let i = 0; i < EMAIL_VERIFICATION_MAX_ATTEMPTS; i += 1) {
        token.registerFailedAttempt(now);
      }

      expect(token.attempts).toBe(EMAIL_VERIFICATION_MAX_ATTEMPTS);
      expect(token.invalidated).toBe(true);
      const events = token.pullEvents();
      const invalidated = events.find((e) => e.type === EMAIL_VERIFICATION_INVALIDATED);
      expect(invalidated?.payload).toMatchObject({ reason: 'too_many_attempts' });
    });

    it('no-op once invalidated or consumed', () => {
      const token = issue();
      token.pullEvents();
      token.invalidate('replaced', new Date('2026-01-01T01:00:00Z'));
      const beforeAttempts = token.attempts;
      token.pullEvents();
      token.registerFailedAttempt(new Date('2026-01-01T02:00:00Z'));
      expect(token.attempts).toBe(beforeAttempts);
    });
  });

  describe('invalidate', () => {
    it('records invalidated event with reason', () => {
      const token = issue();
      token.pullEvents();
      token.invalidate('replaced', new Date('2026-01-01T01:00:00Z'));
      const events = token.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(EMAIL_VERIFICATION_INVALIDATED);
      expect(events[0]?.payload).toMatchObject({ reason: 'replaced' });
    });

    it('idempotent', () => {
      const token = issue();
      token.pullEvents();
      token.invalidate('replaced', new Date('2026-01-01T01:00:00Z'));
      token.pullEvents();
      token.invalidate('too_many_attempts', new Date('2026-01-01T02:00:00Z'));
      expect(token.pullEvents()).toHaveLength(0);
    });
  });
});
