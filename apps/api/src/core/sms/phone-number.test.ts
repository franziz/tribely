import { describe, expect, it } from 'vitest';
import { AppError } from '../errors/app-error.js';
import { PhoneNumber, type E164Phone } from './phone-number.js';

describe('PhoneNumber', () => {
  describe('create — valid E.164 numbers', () => {
    const validNumbers = [
      '+6591234567', // Singapore mobile (10 digits)
      '+6512345678', // Singapore (10 digits)
      '+12125550100', // US (12 digits)
      '+447911123456', // UK (13 digits)
      '+81312345678', // Japan (12 digits)
      '+919876543210', // India (13 digits)
      '+15551234567', // US with area code (12 digits)
      '+9991234567', // 10-digit, country code 999
    ];

    it.each(validNumbers)('accepts %s', (raw) => {
      expect(() => PhoneNumber.create(raw)).not.toThrow();
    });

    it('returns an object with the E164Phone value', () => {
      const phone = PhoneNumber.create('+6591234567');
      expect(phone.value).toBe('+6591234567');
    });

    it('branded type round-trips — value is assignable to E164Phone', () => {
      const phone = PhoneNumber.create('+6591234567');
      // Compile-time check: if this assignment type-checks, the branding works.
      const typed: E164Phone = phone.value;
      expect(typed).toBe('+6591234567');
    });

    it('trims leading/trailing whitespace before validating', () => {
      const phone = PhoneNumber.create('  +6591234567  ');
      expect(phone.value).toBe('+6591234567');
    });
  });

  describe('create — invalid inputs', () => {
    const invalidNumbers = [
      ['no leading +', '6591234567'],
      ['country digit is 0', '+0591234567'],
      ['too short (6 digits total)', '+12345'],
      ['too long (16 digits total)', '+1234567890123456'],
      ['contains spaces', '+65 9123 4567'],
      ['contains dashes', '+65-9123-4567'],
      ['empty string', ''],
      ['only +', '+'],
      ['letters', '+65ABCDEFG'],
    ];

    it.each(invalidNumbers)('rejects %s: %s', (_label, raw) => {
      expect(() => PhoneNumber.create(raw)).toThrow(AppError);
    });

    it('throws AppError with VALIDATION_ERROR code', () => {
      try {
        PhoneNumber.create('not-a-phone');
        expect.fail('Should have thrown');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        expect((err as AppError).code).toBe('VALIDATION_ERROR');
      }
    });

    it('error message includes the invalid input', () => {
      try {
        PhoneNumber.create('bad-input');
        expect.fail('Should have thrown');
      } catch (err) {
        expect((err as AppError).message).toContain('bad-input');
      }
    });
  });
});
