import type { User as UserRow } from '@prisma/client';
import { describe, expect, it } from 'vitest';
import { toRow, toUser } from './user.mapper.js';

const BASE_DATE = new Date('2026-01-01T00:00:00Z');

const BASE_ROW: UserRow = {
  id: 'user_1',
  email: 'a@b.co',
  displayName: 'Alice',
  createdAt: BASE_DATE,
  updatedAt: BASE_DATE,
  emailVerifiedAt: null,
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
  isAdmin: false,
  safetyReminderSeenAt: null,
};

describe('user mapper', () => {
  describe('toUser (DB → domain)', () => {
    it('round-trips phone=null + phoneVerifiedAt=null', () => {
      const user = toUser(BASE_ROW);
      expect(user.phone).toBeNull();
      expect(user.phoneVerifiedAt).toBeNull();
      expect(user.isPhoneVerified()).toBe(false);
    });

    it('round-trips a verified phone number', () => {
      const phoneVerifiedAt = new Date('2026-03-01T10:00:00Z');
      const row: UserRow = { ...BASE_ROW, phone: '+6591234567', phoneVerifiedAt };
      const user = toUser(row);
      expect(user.phone?.value).toBe('+6591234567');
      expect(user.phoneVerifiedAt).toEqual(phoneVerifiedAt);
      expect(user.isPhoneVerified()).toBe(true);
    });

    it('throws on invalid stored phone value (data integrity guard)', () => {
      const row: UserRow = { ...BASE_ROW, phone: 'not-a-phone' };
      expect(() => toUser(row)).toThrow();
    });

    it('round-trips selfie fields — locked state', () => {
      const lockedAt = new Date('2026-05-03T08:00:00Z');
      const row: UserRow = {
        ...BASE_ROW,
        selfieStatus: 'rejected',
        selfieAttemptCount: 3,
        selfieLastFailureCategory: 'poor_lighting',
        selfieAppealLockedAt: lockedAt,
      };
      const user = toUser(row);
      expect(user.selfieStatus).toBe('rejected');
      expect(user.selfieAttemptCount).toBe(3);
      expect(user.selfieLastFailureCategory).toBe('poor_lighting');
      expect(user.selfieAppealLockedAt).toEqual(lockedAt);
    });

    it('coerces unknown selfieLastFailureCategory to null (DB drift guard)', () => {
      const row: UserRow = {
        ...BASE_ROW,
        selfieLastFailureCategory: 'unknown_value_from_future',
      };
      const user = toUser(row);
      expect(user.selfieLastFailureCategory).toBeNull();
    });

    it('coerces unknown selfieStatus to null (DB drift guard)', () => {
      const row: UserRow = {
        ...BASE_ROW,
        selfieStatus: 'unknown_status',
      };
      const user = toUser(row);
      expect(user.selfieStatus).toBeNull();
    });
  });

  describe('toRow (domain → DB)', () => {
    it('round-trips phone=null', () => {
      const row = toRow(toUser(BASE_ROW));
      expect(row.phone).toBeNull();
      expect(row.phoneVerifiedAt).toBeNull();
    });

    it('round-trips phone + phoneVerifiedAt through toUser → toRow', () => {
      const phoneVerifiedAt = new Date('2026-03-01T10:00:00Z');
      const input: UserRow = { ...BASE_ROW, phone: '+6591234567', phoneVerifiedAt };
      const row = toRow(toUser(input));
      expect(row.phone).toBe('+6591234567');
      expect(row.phoneVerifiedAt).toEqual(phoneVerifiedAt);
    });

    it('preserves phone-only (no phoneVerifiedAt) through toUser → toRow', () => {
      // phone present in DB but phoneVerifiedAt null (revoked state)
      const input: UserRow = { ...BASE_ROW, phone: '+6591234567', phoneVerifiedAt: null };
      const row = toRow(toUser(input));
      expect(row.phone).toBe('+6591234567');
      expect(row.phoneVerifiedAt).toBeNull();
    });

    it('round-trips selfie locked state through toUser → toRow', () => {
      const lockedAt = new Date('2026-05-03T08:00:00Z');
      const input: UserRow = {
        ...BASE_ROW,
        selfieStatus: 'rejected',
        selfieAttemptCount: 3,
        selfieLastFailureCategory: 'quality_too_low',
        selfieAppealLockedAt: lockedAt,
      };
      const row = toRow(toUser(input));
      expect(row.selfieStatus).toBe('rejected');
      expect(row.selfieAttemptCount).toBe(3);
      expect(row.selfieLastFailureCategory).toBe('quality_too_low');
      expect(row.selfieAppealLockedAt).toEqual(lockedAt);
    });

    it('round-trips null selfie fields through toUser → toRow', () => {
      const row = toRow(toUser(BASE_ROW));
      expect(row.selfieStatus).toBeNull();
      expect(row.selfieAttemptCount).toBe(0);
      expect(row.selfieLastFailureCategory).toBeNull();
      expect(row.selfieAppealLockedAt).toBeNull();
    });

    it('round-trips deletedAt=null (active account) through toUser → toRow', () => {
      const row = toRow(toUser(BASE_ROW));
      expect(row.deletedAt).toBeNull();
    });

    it('round-trips deletedAt non-null (tombstoned account) through toUser → toRow', () => {
      const tombstonedAt = new Date('2026-05-19T12:00:00Z');
      const input: UserRow = { ...BASE_ROW, deletedAt: tombstonedAt };
      const row = toRow(toUser(input));
      expect(row.deletedAt).toEqual(tombstonedAt);
    });

    it('round-trips isAdmin=false (default) through toUser → toRow', () => {
      const row = toRow(toUser(BASE_ROW));
      expect(row.isAdmin).toBe(false);
    });

    it('round-trips isAdmin=true (admin account) through toUser → toRow', () => {
      const input: UserRow = { ...BASE_ROW, isAdmin: true };
      const row = toRow(toUser(input));
      expect(row.isAdmin).toBe(true);
    });
  });
});
