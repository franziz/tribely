import { describe, expect, it } from 'vitest';
import { PASSWORD_RESET_REQUESTED } from '../events/password-reset-requested.event.js';
import { PASSWORD_RESET_TOKEN_CONSUMED } from '../events/password-reset-token-consumed.event.js';
import { PASSWORD_RESET_TOKEN_INVALIDATED } from '../events/password-reset-token-invalidated.event.js';
import { ONE_TIME_CODE_MAX_ATTEMPTS } from '../value-objects/one-time-code-lifecycle.js';
import { PasswordResetToken } from './password-reset-token.js';

const issue = (overrides: { now?: Date; expiresAt?: Date } = {}): PasswordResetToken => {
  const now = overrides.now ?? new Date('2026-01-01T00:00:00Z');
  const expiresAt = overrides.expiresAt ?? new Date(now.getTime() + 24 * 60 * 60 * 1000);
  return PasswordResetToken.issue({
    id: 'tok_pr_1',
    userId: 'user_1',
    codeHash: 'hash',
    expiresAt,
    now,
  });
};

describe('PasswordResetToken', () => {
  describe('issue', () => {
    it('records passwordResetRequested event', () => {
      const token = issue();
      const events = token.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(PASSWORD_RESET_REQUESTED);
      expect(events[0]?.payload).toMatchObject({ tokenId: 'tok_pr_1', userId: 'user_1' });
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
      expect(events[0]?.type).toBe(PASSWORD_RESET_TOKEN_CONSUMED);
    });

    it('idempotent — second call is a no-op', () => {
      const token = issue();
      token.pullEvents();
      token.consume(new Date('2026-01-01T01:00:00Z'));
      token.pullEvents();
      token.consume(new Date('2026-01-01T02:00:00Z'));
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
      token.registerFailedAttempt(new Date('2026-01-01T01:00:00Z'));
      expect(token.attempts).toBe(1);
      expect(token.invalidated).toBe(false);
    });

    it('auto-invalidates once attempts hits the cap', () => {
      const token = issue();
      token.pullEvents();
      const now = new Date('2026-01-01T01:00:00Z');

      for (let i = 0; i < ONE_TIME_CODE_MAX_ATTEMPTS; i += 1) {
        token.registerFailedAttempt(now);
      }

      expect(token.attempts).toBe(ONE_TIME_CODE_MAX_ATTEMPTS);
      expect(token.invalidated).toBe(true);
      const events = token.pullEvents();
      const invalidated = events.find((e) => e.type === PASSWORD_RESET_TOKEN_INVALIDATED);
      expect(invalidated?.payload).toMatchObject({ reason: 'too_many_attempts' });
    });

    it('no-op once invalidated', () => {
      const token = issue();
      token.pullEvents();
      token.invalidate('replaced', new Date('2026-01-01T01:00:00Z'));
      token.pullEvents();
      token.registerFailedAttempt(new Date('2026-01-01T02:00:00Z'));
      expect(token.attempts).toBe(0);
    });
  });

  describe('invalidate', () => {
    it('records invalidated event with reason', () => {
      const token = issue();
      token.pullEvents();
      token.invalidate('replaced', new Date('2026-01-01T01:00:00Z'));
      const events = token.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(PASSWORD_RESET_TOKEN_INVALIDATED);
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
