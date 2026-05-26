import { describe, expect, it } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import { ReportReason } from '../value-objects/report-reason.js';
import { ReportTarget } from '../value-objects/report-target.js';
import { ReportComment } from '../value-objects/report-comment.js';
import { REPORT_FILED } from '../events/report-filed.event.js';
import { REPORT_ESCALATED } from '../events/report-escalated.event.js';
import { REPORT_RESOLVED } from '../events/report-resolved.event.js';
import { Report } from './report.js';

/**
 * Type-safe subcode assertion for synchronous AppError throws.
 * Uses a try/catch to capture the error and `toMatchObject` to check the
 * `details.subcode` field, avoiding `@typescript-eslint/no-unsafe-argument`
 * that fires when passing `expect.objectContaining(...)` to `toThrowError`.
 */
const expectSubcode = (fn: () => void, expectedSubcode: string): void => {
  let caught: unknown;
  try {
    fn();
  } catch (e) {
    caught = e;
  }
  expect(caught).toBeInstanceOf(AppError);
  expect(caught).toMatchObject({ details: { subcode: expectedSubcode } });
};

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

  it('throws overrideRequiresEscalation if overrideReason is passed on a non-escalated report', () => {
    const report = makeReport();
    report.pullEvents();
    expectSubcode(() => {
      report.resolve({
        resolution: 'kept',
        resolvedByUserId: createId(),
        now: new Date(),
        overrideReason: 'some reason',
      });
    }, 'reports.overrideRequiresEscalation');
  });
});

describe('Report.escalate', () => {
  const makeEscalateInput = (overrides: Partial<Parameters<Report['escalate']>[0]> = {}) => ({
    category: 'criminal-content' as const,
    externalRef: 'REF-001',
    escalatedByUserId: createId(),
    now: new Date('2025-06-03T00:00:00Z'),
    ...overrides,
  });

  it('sets escalation state correctly (AC1)', () => {
    const report = makeReport();
    report.pullEvents();
    const input = makeEscalateInput();
    report.escalate(input);
    expect(report.escalatedAt).toEqual(input.now);
    expect(report.escalationCategory).toBe('criminal-content');
    expect(report.externalRef).toBe('REF-001');
    expect(report.escalatedByUserId).toBe(input.escalatedByUserId);
    expect(report.isEscalated).toBe(true);
  });

  it('records reports.reportEscalated event with full post-state snapshot', () => {
    const report = makeReport({ reason: 'harassment' });
    report.pullEvents();
    const input = makeEscalateInput({ category: 'imminent-harm', externalRef: 'SG-2025-007' });
    report.escalate(input);
    const events = report.pullEvents();
    expect(events).toHaveLength(1);
    expect(events[0]?.type).toBe(REPORT_ESCALATED);
    const payload = events[0]?.payload as Record<string, unknown>;
    expect(payload['category']).toBe('imminent-harm');
    expect(payload['externalRef']).toBe('SG-2025-007');
    expect(payload['escalatedByUserId']).toBe(input.escalatedByUserId);
    expect(payload['escalatedAt']).toBe(input.now.toISOString());
    expect(payload['reason']).toBe('harassment');
  });

  it('throws externalRefRequired when externalRef is blank (AC2)', () => {
    const report = makeReport();
    report.pullEvents();
    expectSubcode(() => {
      report.escalate(makeEscalateInput({ externalRef: '   ' }));
    }, 'reports.externalRefRequired');
  });

  it('throws externalRefRequired when externalRef is empty string (AC2)', () => {
    const report = makeReport();
    report.pullEvents();
    expectSubcode(() => {
      report.escalate(makeEscalateInput({ externalRef: '' }));
    }, 'reports.externalRefRequired');
  });

  it('throws reportAlreadyEscalated on second escalation attempt', () => {
    const report = makeReport();
    report.pullEvents();
    report.escalate(makeEscalateInput());
    report.pullEvents();
    expectSubcode(() => {
      report.escalate(makeEscalateInput({ externalRef: 'REF-002' }));
    }, 'reports.reportAlreadyEscalated');
  });

  it('throws reportAlreadyResolved if escalating an already-resolved report', () => {
    const report = makeReport();
    report.pullEvents();
    report.resolve({ resolution: 'hidden', resolvedByUserId: createId(), now: new Date() });
    report.pullEvents();
    expectSubcode(() => {
      report.escalate(makeEscalateInput());
    }, 'reports.reportAlreadyResolved');
  });

  it('does not mutate firstReviewedAt during escalation', () => {
    const report = makeReport();
    report.pullEvents();
    expect(report.firstReviewedAt).toBeNull();
    report.escalate(makeEscalateInput());
    expect(report.firstReviewedAt).toBeNull();
  });
});

describe('Report.resolve (escalated path — AC5)', () => {
  const buildEscalatedReport = (
    category: Parameters<Report['escalate']>[0]['category'] = 'ambiguous-policy',
  ) => {
    const report = makeReport();
    report.pullEvents();
    report.escalate({
      category,
      externalRef: 'REF-001',
      escalatedByUserId: createId(),
      now: new Date('2025-06-03T00:00:00Z'),
    });
    report.pullEvents();
    return report;
  };

  it('resolves when externalInputCount > 0 and no overrideReason', () => {
    const report = buildEscalatedReport();
    expect(() => {
      report.resolve({
        resolution: 'kept',
        resolvedByUserId: createId(),
        now: new Date(),
        externalInputCount: 1,
      });
    }).not.toThrow();
    expect(report.isResolved).toBe(true);
  });

  it('resolves when overrideReason is non-empty and category allows override', () => {
    const report = buildEscalatedReport('ambiguous-policy');
    expect(() => {
      report.resolve({
        resolution: 'kept',
        resolvedByUserId: createId(),
        now: new Date(),
        overrideReason: 'Reviewed with legal; cleared.',
        externalInputCount: 0,
      });
    }).not.toThrow();
    expect(report.isResolved).toBe(true);
  });

  it('throws escalationResolveBlocked when no externalInputCount and no overrideReason (AC5)', () => {
    const report = buildEscalatedReport();
    expectSubcode(() => {
      report.resolve({
        resolution: 'kept',
        resolvedByUserId: createId(),
        now: new Date(),
        externalInputCount: 0,
      });
    }, 'reports.escalationResolveBlocked');
  });

  it('throws overrideForbiddenForCategory for criminal-content + overrideReason (AC5)', () => {
    const report = buildEscalatedReport('criminal-content');
    expectSubcode(() => {
      report.resolve({
        resolution: 'hidden',
        resolvedByUserId: createId(),
        now: new Date(),
        overrideReason: 'override attempt',
        externalInputCount: 0,
      });
    }, 'reports.overrideForbiddenForCategory');
  });

  it('throws overrideForbiddenForCategory for imminent-harm + overrideReason (AC5)', () => {
    const report = buildEscalatedReport('imminent-harm');
    expectSubcode(() => {
      report.resolve({
        resolution: 'hidden',
        resolvedByUserId: createId(),
        now: new Date(),
        overrideReason: 'override attempt',
        externalInputCount: 0,
      });
    }, 'reports.overrideForbiddenForCategory');
  });

  it('allows resolve for criminal-content when externalInputCount > 0 (no override)', () => {
    const report = buildEscalatedReport('criminal-content');
    expect(() => {
      report.resolve({
        resolution: 'hidden',
        resolvedByUserId: createId(),
        now: new Date(),
        externalInputCount: 1,
      });
    }).not.toThrow();
    expect(report.isResolved).toBe(true);
  });

  it('throws overrideReasonRequired when overrideReason is blank string', () => {
    const report = buildEscalatedReport('ambiguous-policy');
    expectSubcode(() => {
      report.resolve({
        resolution: 'kept',
        resolvedByUserId: createId(),
        now: new Date(),
        overrideReason: '   ',
        externalInputCount: 0,
      });
    }, 'reports.overrideReasonRequired');
  });
});
