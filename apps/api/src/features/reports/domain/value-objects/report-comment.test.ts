import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { ReportComment } from './report-comment.js';

describe('ReportComment', () => {
  it('returns null for null input', () => {
    expect(ReportComment.create(null)).toBeNull();
  });

  it('returns null for undefined input', () => {
    expect(ReportComment.create(undefined)).toBeNull();
  });

  it('returns null for empty string', () => {
    expect(ReportComment.create('')).toBeNull();
  });

  it('returns null for whitespace-only string', () => {
    expect(ReportComment.create('   ')).toBeNull();
  });

  it('creates a comment from a valid string', () => {
    const comment = ReportComment.create('This is spam');
    expect(comment).not.toBeNull();
    expect(comment?.value).toBe('This is spam');
  });

  it('trims surrounding whitespace', () => {
    const comment = ReportComment.create('  hello  ');
    expect(comment?.value).toBe('hello');
  });

  it('creates a comment exactly at the max length', () => {
    const exactly500 = 'a'.repeat(500);
    const comment = ReportComment.create(exactly500);
    expect(comment?.value).toBe(exactly500);
  });

  it('throws validation error for comment exceeding max length', () => {
    const tooLong = 'a'.repeat(501);
    expect(() => ReportComment.create(tooLong)).toThrow(AppError);
    expect(() => ReportComment.create(tooLong)).toThrow(/500 characters/);
  });

  it('equals returns true for same value', () => {
    const a = ReportComment.create('spam');
    const b = ReportComment.create('spam');
    expect(a).not.toBeNull();
    expect(b).not.toBeNull();
    if (a && b) expect(a.equals(b)).toBe(true);
  });

  it('equals returns false for different values', () => {
    const a = ReportComment.create('spam');
    const b = ReportComment.create('harassment');
    expect(a).not.toBeNull();
    expect(b).not.toBeNull();
    if (a && b) expect(a.equals(b)).toBe(false);
  });
});
