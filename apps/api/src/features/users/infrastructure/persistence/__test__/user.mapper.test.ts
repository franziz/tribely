import type { User as UserRow } from '@prisma/client';
import { describe, expect, it } from 'vitest';
import { toRow, toUser } from '../user.mapper.js';

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
  });
});
