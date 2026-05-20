import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Rating } from './rating.js';

describe('Rating', () => {
  it('creates valid integer ratings 1..5', () => {
    for (const v of [1, 2, 3, 4, 5]) {
      const r = Rating.create(v);
      expect(r.value).toBe(v);
    }
  });

  it('rejects 0 (below min)', () => {
    expect(() => Rating.create(0)).toThrow(AppError);
  });

  it('rejects 6 (above max)', () => {
    expect(() => Rating.create(6)).toThrow(AppError);
  });

  it('rejects non-integers', () => {
    expect(() => Rating.create(2.5)).toThrow(AppError);
    expect(() => Rating.create(1.1)).toThrow(AppError);
  });

  it('equals same value', () => {
    const a = Rating.create(3);
    const b = Rating.create(3);
    expect(a.equals(b)).toBe(true);
  });

  it('not equals different value', () => {
    expect(Rating.create(3).equals(Rating.create(4))).toBe(false);
  });
});
