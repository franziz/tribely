import { describe, expect, it } from 'vitest';
import { fileReportBodySchema } from './report.schemas.js';

describe('fileReportBodySchema', () => {
  const validBody = {
    targetType: 'review' as const,
    targetId: 'some-review-id',
    reason: 'spam' as const,
  };

  it('parses a valid body without comment', () => {
    const result = fileReportBodySchema.safeParse(validBody);
    expect(result.success).toBe(true);
  });

  it('parses a valid body with comment', () => {
    const result = fileReportBodySchema.safeParse({ ...validBody, comment: 'this is spam' });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.comment).toBe('this is spam');
    }
  });

  it('rejects targetType other than review', () => {
    expect(fileReportBodySchema.safeParse({ ...validBody, targetType: 'user' }).success).toBe(
      false,
    );
    expect(fileReportBodySchema.safeParse({ ...validBody, targetType: 'event' }).success).toBe(
      false,
    );
    expect(fileReportBodySchema.safeParse({ ...validBody, targetType: 'post' }).success).toBe(
      false,
    );
  });

  it('rejects invalid reason', () => {
    expect(fileReportBodySchema.safeParse({ ...validBody, reason: 'not_a_reason' }).success).toBe(
      false,
    );
  });

  it('rejects comment exceeding 500 chars', () => {
    const tooLong = 'a'.repeat(501);
    expect(fileReportBodySchema.safeParse({ ...validBody, comment: tooLong }).success).toBe(false);
  });

  it('rejects missing targetId', () => {
    const { targetId: _omit, ...rest } = validBody;
    expect(fileReportBodySchema.safeParse(rest).success).toBe(false);
  });

  it('rejects empty targetId', () => {
    expect(fileReportBodySchema.safeParse({ ...validBody, targetId: '' }).success).toBe(false);
  });
});
