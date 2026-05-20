import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { ReviewComment } from './review-comment.js';

describe('ReviewComment', () => {
  it('creates a comment for non-empty input', () => {
    const c = ReviewComment.create('Great person!');
    expect(c).not.toBeNull();
    expect(c?.value).toBe('Great person!');
  });

  it('trims whitespace from input', () => {
    const c = ReviewComment.create('  hello  ');
    expect(c?.value).toBe('hello');
  });

  it('returns null for empty string', () => {
    expect(ReviewComment.create('')).toBeNull();
  });

  it('returns null for whitespace-only string', () => {
    expect(ReviewComment.create('   ')).toBeNull();
    expect(ReviewComment.create('\t\n')).toBeNull();
  });

  it('accepts exactly 500 characters', () => {
    const c = ReviewComment.create('a'.repeat(500));
    expect(c?.value.length).toBe(500);
  });

  it('rejects 501 characters', () => {
    expect(() => ReviewComment.create('a'.repeat(501))).toThrow(AppError);
  });

  it('equals same value', () => {
    const a = ReviewComment.create('hello');
    const b = ReviewComment.create('hello');
    expect(a).not.toBeNull();
    expect(b).not.toBeNull();
    if (a !== null && b !== null) {
      expect(a.equals(b)).toBe(true);
    }
  });

  it('not equals different value', () => {
    const a = ReviewComment.create('hello');
    const b = ReviewComment.create('world');
    expect(a).not.toBeNull();
    expect(b).not.toBeNull();
    if (a !== null && b !== null) {
      expect(a.equals(b)).toBe(false);
    }
  });
});
