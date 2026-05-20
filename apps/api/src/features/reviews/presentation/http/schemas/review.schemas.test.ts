import { describe, expect, it } from 'vitest';
import {
  submitReviewBodySchema,
  editReviewBodySchema,
  listReviewsQuerySchema,
} from './review.schemas.js';

describe('submitReviewBodySchema', () => {
  it('accepts valid input', () => {
    const result = submitReviewBodySchema.safeParse({
      ratedUserId: 'user_123',
      rating: 3,
      comment: 'Nice event',
    });
    expect(result.success).toBe(true);
  });

  it('accepts no comment (optional)', () => {
    const result = submitReviewBodySchema.safeParse({
      ratedUserId: 'user_123',
      rating: 5,
    });
    expect(result.success).toBe(true);
  });

  it('rejects rating < 1', () => {
    const result = submitReviewBodySchema.safeParse({ ratedUserId: 'u', rating: 0 });
    expect(result.success).toBe(false);
  });

  it('rejects rating > 5', () => {
    const result = submitReviewBodySchema.safeParse({ ratedUserId: 'u', rating: 6 });
    expect(result.success).toBe(false);
  });

  it('rejects non-integer rating', () => {
    const result = submitReviewBodySchema.safeParse({ ratedUserId: 'u', rating: 3.5 });
    expect(result.success).toBe(false);
  });

  it('rejects comment longer than 500 chars', () => {
    const result = submitReviewBodySchema.safeParse({
      ratedUserId: 'u',
      rating: 3,
      comment: 'a'.repeat(501),
    });
    expect(result.success).toBe(false);
  });

  it('accepts exactly 500-char comment', () => {
    const result = submitReviewBodySchema.safeParse({
      ratedUserId: 'u',
      rating: 3,
      comment: 'a'.repeat(500),
    });
    expect(result.success).toBe(true);
  });
});

describe('editReviewBodySchema', () => {
  it('accepts valid input', () => {
    const result = editReviewBodySchema.safeParse({ rating: 4, comment: 'Updated' });
    expect(result.success).toBe(true);
  });

  it('accepts no comment', () => {
    const result = editReviewBodySchema.safeParse({ rating: 2 });
    expect(result.success).toBe(true);
  });

  it('rejects invalid rating', () => {
    const result = editReviewBodySchema.safeParse({ rating: 99 });
    expect(result.success).toBe(false);
  });
});

describe('listReviewsQuerySchema', () => {
  it('defaults limit to 20', () => {
    const result = listReviewsQuerySchema.safeParse({});
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.limit).toBe(20);
  });

  it('coerces string limit', () => {
    const result = listReviewsQuerySchema.safeParse({ limit: '10' });
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.limit).toBe(10);
  });

  it('rejects limit > 100', () => {
    const result = listReviewsQuerySchema.safeParse({ limit: '200' });
    expect(result.success).toBe(false);
  });
});
