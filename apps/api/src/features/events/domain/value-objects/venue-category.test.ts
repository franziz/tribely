import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { VenueCategory } from './venue-category.js';

describe('VenueCategory', () => {
  describe('create', () => {
    it.each(VenueCategory.VALUES)('accepts "%s"', (value) => {
      const cat = VenueCategory.create(value);
      expect(cat.value).toBe(value);
    });

    it('throws AppError.validation on unknown value', () => {
      expect(() => VenueCategory.create('office')).toThrowError(AppError);
      expect(() => VenueCategory.create('')).toThrowError(/Invalid venue category/);
    });
  });

  describe('isValid', () => {
    it('narrows known values', () => {
      expect(VenueCategory.isValid('park')).toBe(true);
      expect(VenueCategory.isValid('office')).toBe(false);
    });
  });

  describe('isPublic', () => {
    it.each(VenueCategory.PUBLIC_VALUES)('returns true for public value "%s"', (value) => {
      const cat = VenueCategory.create(value);
      expect(cat.isPublic()).toBe(true);
    });

    const privateValues = VenueCategory.VALUES.filter(
      (v) => !(VenueCategory.PUBLIC_VALUES as readonly string[]).includes(v),
    );
    it.each(privateValues)('returns false for private value "%s"', (value) => {
      const cat = VenueCategory.create(value);
      expect(cat.isPublic()).toBe(false);
    });
  });

  describe('equals', () => {
    it('compares by value', () => {
      const a = VenueCategory.create('park');
      const b = VenueCategory.create('park');
      const c = VenueCategory.create('bar');
      expect(a.equals(b)).toBe(true);
      expect(a.equals(c)).toBe(false);
    });
  });

  describe('toString', () => {
    it('returns the raw string value', () => {
      expect(VenueCategory.create('museum').toString()).toBe('museum');
    });
  });

  describe('VALUES has 18 entries', () => {
    it('has exactly 18 values', () => {
      expect(VenueCategory.VALUES).toHaveLength(18);
    });
  });

  describe('PUBLIC_VALUES has 12 entries', () => {
    it('has exactly 12 values', () => {
      expect(VenueCategory.PUBLIC_VALUES).toHaveLength(12);
    });
  });
});
