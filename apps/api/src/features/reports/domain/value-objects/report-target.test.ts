import { describe, expect, it } from 'vitest';
import { ReportTarget, REPORT_TARGET_TYPES } from './report-target.js';

describe('ReportTarget', () => {
  it.each(REPORT_TARGET_TYPES)('creates valid target type: %s', (type) => {
    const target = ReportTarget.create(type, 'some-id');
    expect(target.type).toBe(type);
    expect(target.id).toBe('some-id');
  });

  it('throws for unknown target type', () => {
    expect(() => ReportTarget.create('post', 'some-id')).toThrow(/Invalid report target type/);
  });

  it('throws for empty id', () => {
    expect(() => ReportTarget.create('review', '')).toThrow(/must not be empty/);
    expect(() => ReportTarget.create('review', '   ')).toThrow(/must not be empty/);
  });

  it('equals returns true for same type and id', () => {
    const a = ReportTarget.create('review', 'abc');
    const b = ReportTarget.create('review', 'abc');
    expect(a.equals(b)).toBe(true);
  });

  it('equals returns false for different type', () => {
    const a = ReportTarget.create('review', 'abc');
    const b = ReportTarget.create('user', 'abc');
    expect(a.equals(b)).toBe(false);
  });

  it('equals returns false for different id', () => {
    const a = ReportTarget.create('review', 'abc');
    const b = ReportTarget.create('review', 'xyz');
    expect(a.equals(b)).toBe(false);
  });
});
