import { PhoneNumber } from '@/core/sms/phone-number.js';
import { describe, expect, it } from 'vitest';
import { SELFIE_APPEAL_APPROVED } from '../events/selfie-appeal-approved.event.js';
import { SELFIE_REJECTED } from '../events/selfie-rejected.event.js';
import { USER_ACCOUNT_DELETED } from '../events/user-account-deleted.event.js';
import { USER_PHONE_VERIFICATION_REVOKED } from '../events/user-phone-verification-revoked.event.js';
import { USER_PHONE_VERIFIED } from '../events/user-phone-verified.event.js';
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
        selfieStatus: null,
        selfieAttemptCount: 0,
        selfieLastFailureCategory: null,
        selfieAppealLockedAt: null,
        deletedAt: null,
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
        selfieStatus: null,
        selfieAttemptCount: 0,
        selfieLastFailureCategory: null,
        selfieAppealLockedAt: null,
        deletedAt: null,
      });
      expect(user.phone?.value).toBe('+6591234567');
      expect(user.phoneVerifiedAt).toEqual(verifiedAt);
      expect(user.isPhoneVerified()).toBe(true);
    });

    it('preserves selfie fields from persistence', () => {
      const lockedAt = new Date('2026-05-01T08:00:00Z');
      const user = User.rehydrate({
        id: 'user_1',
        email: Email.create('a@b.co'),
        displayName: DisplayName.create('Alice'),
        createdAt: new Date('2026-01-01T00:00:00Z'),
        updatedAt: lockedAt,
        emailVerifiedAt: null,
        bio: null,
        avatarUrl: null,
        languages: [],
        interests: [],
        currentCity: null,
        travelerType: null,
        phone: null,
        phoneVerifiedAt: null,
        selfieStatus: 'rejected',
        selfieAttemptCount: 3,
        selfieLastFailureCategory: 'poor_lighting',
        selfieAppealLockedAt: lockedAt,
        deletedAt: null,
      });
      expect(user.selfieStatus).toBe('rejected');
      expect(user.selfieAttemptCount).toBe(3);
      expect(user.selfieLastFailureCategory).toBe('poor_lighting');
      expect(user.selfieAppealLockedAt).toEqual(lockedAt);
    });
  });

  describe('verifyPhone', () => {
    it('records users.userUpdated + users.userPhoneVerified on first verification', () => {
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
      expect(events[1]?.type).toBe(USER_PHONE_VERIFIED);
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

    it('users.userPhoneVerified payload has correct fields', () => {
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
      expect(events[1]?.type).toBe(USER_PHONE_VERIFIED);
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

    it('records users.userUpdated + users.userPhoneVerificationRevoked', () => {
      const user = buildVerifiedUser();
      const now = new Date('2026-04-01T00:00:00Z');

      user.revokePhoneVerificationOnTakeover('user_2', 'hash_abc', now);

      const events = user.pullEvents();
      expect(events).toHaveLength(2);
      expect(events[0]?.type).toBe(USER_UPDATED);
      expect(events[1]?.type).toBe(USER_PHONE_VERIFICATION_REVOKED);
    });

    it('users.userPhoneVerificationRevoked payload has correct fields', () => {
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

  describe('recordSelfieRejection', () => {
    it('increments attemptCount, sets status=rejected, records failure category', () => {
      const user = buildUser();
      user.pullEvents();
      const now = new Date('2026-05-01T08:00:00Z');

      user.recordSelfieRejection({ failureCategory: 'poor_lighting', now });

      expect(user.selfieAttemptCount).toBe(1);
      expect(user.selfieStatus).toBe('rejected');
      expect(user.selfieLastFailureCategory).toBe('poor_lighting');
      expect(user.selfieAppealLockedAt).toBeNull();
      expect(user.updatedAt).toEqual(now);
    });

    it('emits users.selfieRejected with full snapshot (no lock on first attempt)', () => {
      const user = buildUser();
      user.pullEvents();
      const now = new Date('2026-05-01T08:00:00Z');

      user.recordSelfieRejection({ failureCategory: 'face_not_visible', now });

      const events = user.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(SELFIE_REJECTED);
      expect(events[0]?.payload).toMatchObject({
        userId: 'user_1',
        failureCategory: 'face_not_visible',
        attemptCount: 1,
        lockedAt: null,
      });
    });

    it('sets selfieAppealLockedAt on third rejection (attempt >= 3)', () => {
      const user = buildUser();
      user.pullEvents();

      user.recordSelfieRejection({
        failureCategory: 'quality_too_low',
        now: new Date('2026-05-01T08:00:00Z'),
      });
      user.recordSelfieRejection({
        failureCategory: 'quality_too_low',
        now: new Date('2026-05-02T08:00:00Z'),
      });
      user.pullEvents();

      const lockTime = new Date('2026-05-03T08:00:00Z');
      user.recordSelfieRejection({ failureCategory: 'other', now: lockTime });

      expect(user.selfieAttemptCount).toBe(3);
      expect(user.selfieAppealLockedAt).toEqual(lockTime);

      const events = user.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.payload).toMatchObject({
        attemptCount: 3,
        lockedAt: lockTime.toISOString(),
      });
    });

    it('locks on attempt 4 as well (>= 3 is the threshold)', () => {
      const user = buildUser();
      user.pullEvents();

      for (let i = 0; i < 3; i++) {
        user.recordSelfieRejection({
          failureCategory: 'poor_lighting',
          now: new Date(`2026-05-0${String(i + 1)}T08:00:00Z`),
        });
      }
      user.pullEvents();

      const lockTime2 = new Date('2026-05-10T08:00:00Z');
      user.recordSelfieRejection({ failureCategory: 'other', now: lockTime2 });

      expect(user.selfieAttemptCount).toBe(4);
      expect(user.selfieAppealLockedAt).toEqual(lockTime2);
    });
  });

  describe('recordSelfieAppealApproved', () => {
    const buildLockedUser = (): User => {
      const user = buildUser();
      user.pullEvents();
      user.recordSelfieRejection({
        failureCategory: 'poor_lighting',
        now: new Date('2026-05-01T08:00:00Z'),
      });
      user.recordSelfieRejection({
        failureCategory: 'face_not_visible',
        now: new Date('2026-05-02T08:00:00Z'),
      });
      user.recordSelfieRejection({
        failureCategory: 'quality_too_low',
        now: new Date('2026-05-03T08:00:00Z'),
      });
      user.pullEvents();
      return user;
    };

    it('clears selfieAppealLockedAt and sets status=pending', () => {
      const user = buildLockedUser();
      const now = new Date('2026-05-10T09:00:00Z');

      user.recordSelfieAppealApproved({ now });

      expect(user.selfieAppealLockedAt).toBeNull();
      expect(user.selfieStatus).toBe('pending');
      expect(user.updatedAt).toEqual(now);
    });

    it('PRESERVES selfieAttemptCount (does not reset)', () => {
      const user = buildLockedUser();

      user.recordSelfieAppealApproved({ now: new Date('2026-05-10T09:00:00Z') });

      expect(user.selfieAttemptCount).toBe(3);
    });

    it('PRESERVES selfieLastFailureCategory (does not clear)', () => {
      const user = buildLockedUser();

      user.recordSelfieAppealApproved({ now: new Date('2026-05-10T09:00:00Z') });

      expect(user.selfieLastFailureCategory).toBe('quality_too_low');
    });

    it('emits users.selfieAppealApproved with clearedAt payload', () => {
      const user = buildLockedUser();
      const now = new Date('2026-05-10T09:00:00Z');

      user.recordSelfieAppealApproved({ now });

      const events = user.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(SELFIE_APPEAL_APPROVED);
      expect(events[0]?.payload).toMatchObject({
        userId: 'user_1',
        clearedAt: now.toISOString(),
      });
    });
  });

  describe('tombstone', () => {
    const buildFullUser = (): User => {
      const user = User.register({
        id: 'user_1',
        email: Email.create('alice@example.com'),
        displayName: DisplayName.create('Alice'),
        now: new Date('2026-01-01T00:00:00Z'),
      });
      user.pullEvents(); // flush register event
      user.verifyPhone(PHONE_SG, new Date('2026-03-01T10:00:00Z'));
      user.pullEvents();
      return user;
    };

    it('sets deletedAt to the supplied timestamp', () => {
      const user = buildFullUser();
      const now = new Date('2026-05-19T12:00:00Z');

      user.tombstone(now);

      expect(user.deletedAt).toEqual(now);
    });

    it('bumps updatedAt to the tombstone timestamp', () => {
      const user = buildFullUser();
      const now = new Date('2026-05-19T12:00:00Z');

      user.tombstone(now);

      expect(user.updatedAt).toEqual(now);
    });

    it('replaces email with a deleted-* placeholder that passes format validation', () => {
      const user = buildFullUser();
      user.tombstone(new Date('2026-05-19T12:00:00Z'));

      expect(user.email.value).toMatch(/^deleted-[a-z0-9]+@deleted\.tribely\.local$/);
    });

    it('replaces displayName with a Deleted user placeholder', () => {
      const user = buildFullUser();
      user.tombstone(new Date('2026-05-19T12:00:00Z'));

      expect(user.displayName.value).toMatch(/^Deleted user [a-z0-9]+$/i);
    });

    it('clears all PII fields to null / empty', () => {
      const user = buildFullUser();
      user.tombstone(new Date('2026-05-19T12:00:00Z'));

      expect(user.bio).toBeNull();
      expect(user.avatarUrl).toBeNull();
      expect(user.currentCity).toBeNull();
      expect(user.travelerType).toBeNull();
      expect(user.phone).toBeNull();
      expect(user.phoneVerifiedAt).toBeNull();
      expect(user.emailVerifiedAt).toBeNull();
      expect(user.selfieStatus).toBeNull();
      expect(user.selfieLastFailureCategory).toBeNull();
      expect(user.selfieAppealLockedAt).toBeNull();
    });

    it('resets selfieAttemptCount to 0 and clears language/interest arrays', () => {
      const user = buildFullUser();
      user.tombstone(new Date('2026-05-19T12:00:00Z'));

      expect(user.selfieAttemptCount).toBe(0);
      expect(user.languages).toHaveLength(0);
      expect(user.interests).toHaveLength(0);
    });

    it('records users.userAccountDeleted with userId + deletedAt', () => {
      const user = buildFullUser();
      const now = new Date('2026-05-19T12:00:00Z');

      user.tombstone(now);

      const events = user.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(USER_ACCOUNT_DELETED);
      expect(events[0]?.payload).toMatchObject({
        userId: 'user_1',
        deletedAt: now.toISOString(),
      });
    });

    it('double tombstone throws (defence-in-depth invariant)', () => {
      const user = buildFullUser();
      const now = new Date('2026-05-19T12:00:00Z');

      user.tombstone(now);
      user.pullEvents();

      expect(() => user.tombstone(now)).toThrow();
    });

    it('preserves id and createdAt (non-PII identity anchor)', () => {
      const user = buildFullUser();
      const createdAt = user.createdAt;

      user.tombstone(new Date('2026-05-19T12:00:00Z'));

      expect(user.id).toBe('user_1');
      expect(user.createdAt).toEqual(createdAt);
    });
  });
});
