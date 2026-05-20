import { describe, expect, it } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import { ReportReason } from '../value-objects/report-reason.js';
import { ReportTarget } from '../value-objects/report-target.js';
import { ReportComment } from '../value-objects/report-comment.js';
import { REPORT_FILED } from '../events/report-filed.event.js';
import { REPORT_RESOLVED } from '../events/report-resolved.event.js';
import { Report } from './report.js';

const makeReport = (
  overrides: Partial<{
    id: string;
    reporterUserId: string;
    targetType: string;
    targetId: string;
    reason: string;
    comment: string | null;
    now: Date;
  }> = {},
) => {
  const now = overrides.now ?? new Date('2025-06-01T00:00:00Z');
  return Report.file({
    id: overrides.id ?? createId(),
    reporterUserId: overrides.reporterUserId ?? createId(),
    target: ReportTarget.create(overrides.targetType ?? 'review', overrides.targetId ?? createId()),
    reason: ReportReason.create(overrides.reason ?? 'spam'),
    comment: overrides.comment !== undefined ? ReportComment.create(overrides.comment) : null,
    now,
  });
};

describe('Report.file', () => {
  it('creates a report with correct initial state', () => {
    const report = makeReport();
    expect(report.firstReviewedAt).toBeNull();
    expect(report.resolvedAt).toBeNull();
    expect(report.resolution).toBeNull();
    expect(report.resolvedByUserId).toBeNull();
    expect(report.isResolved).toBe(false);
  });

  it('records reports.reportFiled event', () => {
    const report = makeReport({ reason: 'spam', comment: 'test comment' });
    const events = report.pullEvents();
    expect(events).toHaveLength(1);
    expect(events[0]?.type).toBe(REPORT_FILED);
    expect(events[0]?.payload).toMatchObject({
      reason: 'spam',
      hasComment: true,
    });
  });

  it('records hasComment=false when no comment', () => {
    const report = makeReport({ comment: null });
    const events = report.pullEvents();
    expect(events[0]?.payload).toMatchObject({ hasComment: false });
  });
});

describe('Report.touch', () => {
  it('sets firstReviewedAt on first call', () => {
    const report = makeReport();
    report.pullEvents(); // clear filed event
    const now = new Date('2025-06-02T00:00:00Z');
    report.touch(now);
    expect(report.firstReviewedAt).toEqual(now);
  });

  it('is idempotent — second touch does not update firstReviewedAt', () => {
    const report = makeReport();
    report.pullEvents();
    const first = new Date('2025-06-02T00:00:00Z');
    const second = new Date('2025-06-03T00:00:00Z');
    report.touch(first);
    report.touch(second);
    expect(report.firstReviewedAt).toEqual(first);
  });

  it('does not record any event', () => {
    const report = makeReport();
    report.pullEvents();
    report.touch(new Date());
    expect(report.pullEvents()).toHaveLength(0);
  });
});

describe('Report.resolve', () => {
  it('sets resolution state correctly', () => {
    const report = makeReport();
    report.pullEvents();
    const moderatorId = createId();
    const now = new Date('2025-06-02T00:00:00Z');
    report.resolve({ resolution: 'hidden', resolvedByUserId: moderatorId, now });
    expect(report.resolvedAt).toEqual(now);
    expect(report.resolution).toBe('hidden');
    expect(report.resolvedByUserId).toBe(moderatorId);
    expect(report.isResolved).toBe(true);
  });

  it('records reports.reportResolved event with full post-state snapshot', () => {
    const now = new Date('2025-06-01T00:00:00Z');
    const report = makeReport({ now });
    report.pullEvents();
    const touchAt = new Date('2025-06-01T01:00:00Z');
    report.touch(touchAt);
    const resolveAt = new Date('2025-06-01T02:00:00Z');
    const moderatorId = createId();
    report.resolve({ resolution: 'kept', resolvedByUserId: moderatorId, now: resolveAt });
    const events = report.pullEvents();
    expect(events).toHaveLength(1);
    expect(events[0]?.type).toBe(REPORT_RESOLVED);
    const payload = events[0]?.payload as Record<string, unknown>;
    expect(payload['resolution']).toBe('kept');
    expect(payload['resolvedByUserId']).toBe(moderatorId);
    expect(payload['firstReviewedAt']).toBe(touchAt.toISOString());
  });

  it('throws ReportAlreadyResolved if already resolved (append-only invariant)', () => {
    const report = makeReport();
    report.pullEvents();
    const moderatorId = createId();
    report.resolve({ resolution: 'hidden', resolvedByUserId: moderatorId, now: new Date() });
    report.pullEvents();
    expect(() => {
      report.resolve({ resolution: 'kept', resolvedByUserId: moderatorId, now: new Date() });
    }).toThrow(AppError);
    expect(() => {
      report.resolve({ resolution: 'kept', resolvedByUserId: moderatorId, now: new Date() });
    }).toThrow(/already been resolved/);
  });
});
