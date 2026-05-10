import { describe, expect, it } from 'vitest';
import { USER_EMAIL_VERIFIED } from '../events/user-email-verified.event.js';
import { DisplayName } from '../value-objects/display-name.js';
import { Email } from '../value-objects/email.js';
import { User } from './user.js';

describe('User aggregate', () => {
  const buildUser = (): User =>
    User.register({
      id: 'user_1',
      email: Email.create('a@b.co'),
      displayName: DisplayName.create('Alice'),
      now: new Date('2026-01-01T00:00:00Z'),
    });

  it('starts unverified', () => {
    const user = buildUser();
    user.pullEvents(); // flush register event
    expect(user.emailVerifiedAt).toBeNull();
    expect(user.isEmailVerified()).toBe(false);
  });

  describe('verifyEmail', () => {
    it('sets emailVerifiedAt + bumps updatedAt + records event', () => {
      const user = buildUser();
      user.pullEvents();
      const now = new Date('2026-02-02T12:00:00Z');

      user.verifyEmail(now);

      expect(user.emailVerifiedAt).toEqual(now);
      expect(user.isEmailVerified()).toBe(true);
      expect(user.updatedAt).toEqual(now);
      const events = user.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(USER_EMAIL_VERIFIED);
      expect(events[0]?.payload).toMatchObject({
        userId: 'user_1',
        email: 'a@b.co',
        verifiedAt: now.toISOString(),
      });
    });

    it('is idempotent — second call is a no-op', () => {
      const user = buildUser();
      user.pullEvents();
      const first = new Date('2026-02-02T12:00:00Z');
      const second = new Date('2026-02-03T12:00:00Z');

      user.verifyEmail(first);
      user.pullEvents();
      user.verifyEmail(second);

      expect(user.emailVerifiedAt).toEqual(first);
      expect(user.pullEvents()).toHaveLength(0);
    });
  });

  describe('rehydrate', () => {
    it('preserves emailVerifiedAt from persistence', () => {
      const verifiedAt = new Date('2026-02-02T12:00:00Z');
      const user = User.rehydrate({
        id: 'user_1',
        email: Email.create('a@b.co'),
        displayName: DisplayName.create('Alice'),
        createdAt: new Date('2026-01-01T00:00:00Z'),
        updatedAt: verifiedAt,
        emailVerifiedAt: verifiedAt,
      });
      expect(user.isEmailVerified()).toBe(true);
      expect(user.emailVerifiedAt).toEqual(verifiedAt);
    });
  });
});
