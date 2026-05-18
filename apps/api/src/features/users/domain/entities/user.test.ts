import { PhoneNumber } from '@/core/sms/phone-number.js';
import { describe, expect, it } from 'vitest';
import { PHONE_VERIFICATION_REVOKED } from '@/features/auth/domain/events/phone-verification-revoked.event.js';
import { PHONE_VERIFIED } from '@/features/auth/domain/events/phone-verified.event.js';
import { USER_EMAIL_VERIFIED } from '../events/user-email-verified.event.js';
import { USER_UPDATED } from '../events/user-updated.event.js';
import { DisplayName } from '../value-objects/display-name.js';
import { Email } from '../value-objects/email.js';
import { User } from './user.js';

const PHONE_SG = PhoneNumber.create('+6591234567');
const PHONE_SG2 = PhoneNumber.create('+6599887766');

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
        bio: null,
        avatarUrl: null,
        languages: [],
        interests: [],
        currentCity: null,
        travelerType: null,
        phone: null,
        phoneVerifiedAt: null,
      });
      expect(user.isEmailVerified()).toBe(true);
      expect(user.emailVerifiedAt).toEqual(verifiedAt);
    });

    it('preserves phone + phoneVerifiedAt from persistence', () => {
      const verifiedAt = new Date('2026-03-01T10:00:00Z');
      const user = User.rehydrate({
        id: 'user_1',
        email: Email.create('a@b.co'),
        displayName: DisplayName.create('Alice'),
        createdAt: new Date('2026-01-01T00:00:00Z'),
        updatedAt: verifiedAt,
        emailVerifiedAt: null,
        bio: null,
        avatarUrl: null,
        languages: [],
        interests: [],
        currentCity: null,
        travelerType: null,
        phone: PHONE_SG,
        phoneVerifiedAt: verifiedAt,
      });
      expect(user.phone?.value).toBe('+6591234567');
      expect(user.phoneVerifiedAt).toEqual(verifiedAt);
      expect(user.isPhoneVerified()).toBe(true);
    });
  });

  describe('verifyPhone', () => {
    it('records users.userUpdated + auth.phoneVerified on first verification', () => {
      const user = buildUser();
      user.pullEvents();
      const now = new Date('2026-03-01T10:00:00Z');

      user.verifyPhone(PHONE_SG, now);

      expect(user.phone?.value).toBe('+6591234567');
      expect(user.phoneVerifiedAt).toEqual(now);
      expect(user.updatedAt).toEqual(now);

      const events = user.pullEvents();
      expect(events).toHaveLength(2);
      expect(events[0]?.type).toBe(USER_UPDATED);
      expect(events[1]?.type).toBe(PHONE_VERIFIED);
    });

    it('snapshot includes phone + phoneVerifiedAt fields', () => {
      const user = buildUser();
      user.pullEvents();
      const now = new Date('2026-03-01T10:00:00Z');

      user.verifyPhone(PHONE_SG, now);

      const events = user.pullEvents();
      const updatedEvent = events[0];
      expect(updatedEvent?.payload).toMatchObject({
        userId: 'user_1',
        phone: '+6591234567',
        phoneVerifiedAt: now.toISOString(),
      });
    });

    it('auth.phoneVerified payload has correct fields', () => {
      const user = buildUser();
      user.pullEvents();
      const now = new Date('2026-03-01T10:00:00Z');

      user.verifyPhone(PHONE_SG, now);

      const events = user.pullEvents();
      const verifiedEvent = events[1];
      expect(verifiedEvent?.payload).toMatchObject({
        userId: 'user_1',
        phoneE164: '+6591234567',
        verifiedAt: now.toISOString(),
      });
    });

    it('is idempotent — second call with same phone records zero events', () => {
      const user = buildUser();
      user.pullEvents();
      const now1 = new Date('2026-03-01T10:00:00Z');
      const now2 = new Date('2026-03-02T10:00:00Z');

      user.verifyPhone(PHONE_SG, now1);
      user.pullEvents(); // flush

      user.verifyPhone(PHONE_SG, now2); // same phone — no-op

      expect(user.pullEvents()).toHaveLength(0);
      expect(user.phoneVerifiedAt).toEqual(now1); // unchanged
    });

    it('records events again when a different phone is verified', () => {
      const user = buildUser();
      user.pullEvents();
      const now1 = new Date('2026-03-01T10:00:00Z');
      const now2 = new Date('2026-03-02T10:00:00Z');

      user.verifyPhone(PHONE_SG, now1);
      user.pullEvents();

      user.verifyPhone(PHONE_SG2, now2); // different phone — real change

      const events = user.pullEvents();
      expect(events).toHaveLength(2);
      expect(events[0]?.type).toBe(USER_UPDATED);
      expect(events[1]?.type).toBe(PHONE_VERIFIED);
      expect(user.phone?.value).toBe('+6599887766');
    });
  });

  describe('revokePhoneVerificationOnTakeover', () => {
    const buildVerifiedUser = (): User => {
      const user = buildUser();
      user.pullEvents();
      user.verifyPhone(PHONE_SG, new Date('2026-03-01T10:00:00Z'));
      user.pullEvents();
      return user;
    };

    it('records users.userUpdated + auth.phoneVerificationRevoked', () => {
      const user = buildVerifiedUser();
      const now = new Date('2026-04-01T00:00:00Z');

      user.revokePhoneVerificationOnTakeover('user_2', 'hash_abc', now);

      const events = user.pullEvents();
      expect(events).toHaveLength(2);
      expect(events[0]?.type).toBe(USER_UPDATED);
      expect(events[1]?.type).toBe(PHONE_VERIFICATION_REVOKED);
    });

    it('auth.phoneVerificationRevoked payload has correct fields', () => {
      const user = buildVerifiedUser();
      const now = new Date('2026-04-01T00:00:00Z');

      user.revokePhoneVerificationOnTakeover('user_2', 'hash_abc', now);

      const events = user.pullEvents();
      const revokedEvent = events[1];
      expect(revokedEvent?.payload).toMatchObject({
        oldUserId: 'user_1',
        newUserId: 'user_2',
        phoneE164Hash: 'hash_abc',
        revokedAt: now.toISOString(),
      });
    });

    it('retains _phone but clears phoneVerifiedAt', () => {
      const user = buildVerifiedUser();
      const now = new Date('2026-04-01T00:00:00Z');

      user.revokePhoneVerificationOnTakeover('user_2', 'hash_abc', now);

      expect(user.phone?.value).toBe('+6591234567'); // retained for audit
      expect(user.phoneVerifiedAt).toBeNull();
      expect(user.isPhoneVerified()).toBe(false);
    });

    it('snapshot phone is retained but phoneVerifiedAt is null', () => {
      const user = buildVerifiedUser();
      const now = new Date('2026-04-01T00:00:00Z');

      user.revokePhoneVerificationOnTakeover('user_2', 'hash_abc', now);

      const events = user.pullEvents();
      expect(events[0]?.payload).toMatchObject({
        phone: '+6591234567',
        phoneVerifiedAt: null,
      });
    });

    it('bumps updatedAt', () => {
      const user = buildVerifiedUser();
      const now = new Date('2026-04-01T00:00:00Z');

      user.revokePhoneVerificationOnTakeover('user_2', 'hash_abc', now);

      expect(user.updatedAt).toEqual(now);
    });
  });
});
