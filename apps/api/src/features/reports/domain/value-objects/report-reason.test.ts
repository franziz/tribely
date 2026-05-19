import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { ReportReason, REPORT_REASON_VALUES } from './report-reason.js';

describe('ReportReason', () => {
  it.each(REPORT_REASON_VALUES)('creates valid reason: %s', (value) => {
    const reason = ReportReason.create(value);
    expect(reason.value).toBe(value);
  });

  it('throws validation error for unknown reason', () => {
    expect(() => ReportReason.create('bad_reason')).toThrow(AppError);
    expect(() => ReportReason.create('bad_reason')).toThrow(/Invalid report reason/);
  });

  it('throws validation error for empty string', () => {
    expect(() => ReportReason.create('')).toThrow(AppError);
  });

  it('equals returns true for same value', () => {
    const a = ReportReason.create('spam');
    const b = ReportReason.create('spam');
    expect(a.equals(b)).toBe(true);
  });

  it('equals returns false for different values', () => {
    const a = ReportReason.create('spam');
    const b = ReportReason.create('harassment');
    expect(a.equals(b)).toBe(false);
  });
});
