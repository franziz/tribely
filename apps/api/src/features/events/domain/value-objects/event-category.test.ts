import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { EventCategory } from './event-category.js';

describe('EventCategory', () => {
  describe('create', () => {
    it.each(EventCategory.VALUES)('accepts "%s"', (value) => {
      const cat = EventCategory.create(value);
      expect(cat.value).toBe(value);
    });

    it('throws AppError.validation on unknown value', () => {
      expect(() => EventCategory.create('parties')).toThrowError(AppError);
      expect(() => EventCategory.create('')).toThrowError(/Invalid event category/);
    });
  });

  describe('isValid', () => {
    it('narrows known values', () => {
      expect(EventCategory.isValid('hike')).toBe(true);
      expect(EventCategory.isValid('parties')).toBe(false);
    });
  });

  describe('equals', () => {
    it('compares by value', () => {
      const a = EventCategory.create('drinks');
      const b = EventCategory.create('drinks');
      const c = EventCategory.create('food');
      expect(a.equals(b)).toBe(true);
      expect(a.equals(c)).toBe(false);
    });
  });
});
