import { describe, expect, it } from 'vitest';
import { PhoneNumber } from './phone-number.js';
import { Sha256PhoneHasher } from './sha256-phone-hasher.js';

const SALT_A = 'a'.repeat(32);
const SALT_B = 'b'.repeat(32);
const PHONE = PhoneNumber.create('+6591234567').value;

describe('Sha256PhoneHasher', () => {
  describe('constructor', () => {
    it('throws when salt is shorter than 32 characters', () => {
      expect(() => new Sha256PhoneHasher('tooshort')).toThrow(
        'PHONE_HASH_SALT must be at least 32 characters',
      );
    });

    it('accepts a salt of exactly 32 characters', () => {
      expect(() => new Sha256PhoneHasher(SALT_A)).not.toThrow();
    });
  });

  describe('hash', () => {
    it('is deterministic: same phone + salt produces the same hash', () => {
      const hasher = new Sha256PhoneHasher(SALT_A);
      expect(hasher.hash(PHONE)).toBe(hasher.hash(PHONE));
    });

    it('is salt-sensitive: different salts produce different hashes for the same phone', () => {
      const hasherA = new Sha256PhoneHasher(SALT_A);
      const hasherB = new Sha256PhoneHasher(SALT_B);
      expect(hasherA.hash(PHONE)).not.toBe(hasherB.hash(PHONE));
    });

    it('returns a 64-character hex string (SHA-256 output)', () => {
      const hasher = new Sha256PhoneHasher(SALT_A);
      const result = hasher.hash(PHONE);
      expect(result).toMatch(/^[0-9a-f]{64}$/);
    });
  });
});
