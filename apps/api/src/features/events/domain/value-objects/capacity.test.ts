import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Capacity } from './capacity.js';

describe('Capacity', () => {
  describe('create', () => {
    it('accepts MIN and MAX boundaries', () => {
      expect(Capacity.create(Capacity.MIN).value).toBe(Capacity.MIN);
      expect(Capacity.create(Capacity.MAX).value).toBe(Capacity.MAX);
    });

    it('rejects values below MIN', () => {
      expect(() => Capacity.create(Capacity.MIN - 1)).toThrowError(AppError);
      expect(() => Capacity.create(0)).toThrowError(/between/);
    });

    it('rejects values above MAX', () => {
      expect(() => Capacity.create(Capacity.MAX + 1)).toThrowError(/between/);
    });

    it('rejects non-integers', () => {
      expect(() => Capacity.create(4.5)).toThrowError(/integer/);
      expect(() => Capacity.create(Number.NaN)).toThrowError(/integer/);
    });
  });

  describe('equals', () => {
    it('compares by value', () => {
      expect(Capacity.create(8).equals(Capacity.create(8))).toBe(true);
      expect(Capacity.create(8).equals(Capacity.create(9))).toBe(false);
    });
  });
});
