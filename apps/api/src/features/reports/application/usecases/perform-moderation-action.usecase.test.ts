import { describe, expect, it, vi } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import { FakeUnitOfWork, FakeEventPublisher, FixedClock, TEST_TX } from '@/core/testing/fakes.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { Report } from '../../domain/entities/report.js';
import { ReportReason } from '../../domain/value-objects/report-reason.js';
import { ReportTarget } from '../../domain/value-objects/report-target.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import type { ReviewRepository } from '@/features/reviews/domain/repositories/review.repository.js';
import { Review } from '@/features/reviews/domain/entities/review.js';
import { Rating } from '@/features/reviews/domain/value-objects/rating.js';
import { ReviewComment } from '@/features/reviews/domain/value-objects/review-comment.js';
import type { RecordModerationActionUseCase } from '@/features/audit/application/usecases/record-moderation-action.usecase.js';
import type { RecordModerationActionInput } from '@/features/audit/application/usecases/record-moderation-action.usecase.js';
import { PerformModerationActionUseCase } from './perform-moderation-action.usecase.js';

const NOW = new Date('2026-05-24T10:00:00Z');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const makeReport = (targetType: 'review' | 'user' = 'review'): Report => {
  const report = Report.file({
    id: createId(),
    reporterUserId: createId(),
    target: ReportTarget.create(targetType, createId()),
    reason: ReportReason.create('spam'),
    comment: null,
    now: new Date('2026-05-20T00:00:00Z'),
  });
  report.pullEvents(); // discard filed event
  return report;
};

/**
 * Build an escalated report rehydrated with the given category and externalInputCount.
 * Used to test the resolve-with-override and escalation-resolve-guard branches.
 */
const makeEscalatedReport = (
  options: {
    targetType?: 'review' | 'user';
    category?: 'ambiguous-policy' | 'external-jurisdiction' | 'criminal-content' | 'imminent-harm';
    externalInputCount?: number;
  } = {},
): Report => {
  const base = makeReport(options.targetType ?? 'review');
  return Report.rehydrate({
    id: base.id,
    reporterUserId: base.reporterUserId,
    target: base.target,
    reason: base.reason,
    comment: base.comment,
    createdAt: base.createdAt,
    firstReviewedAt: null,
    resolvedAt: null,
    resolution: null,
    resolvedByUserId: null,
    escalatedAt: new Date('2026-05-22T00:00:00Z'),
    escalationCategory: options.category ?? 'ambiguous-policy',
    externalRef: 'CASE-100',
    escalatedByUserId: createId(),
    externalInputCount: options.externalInputCount ?? 0,
  });
};

const makeReview = (comment = 'Nice event!'): Review => {
  return Review.rehydrate({
    id: createId(),
    eventId: createId(),
    raterUserId: createId(),
    ratedUserId: createId(),
    rating: Rating.create(4),
    comment: ReviewComment.create(comment),
    createdAt: new Date('2026-05-19T00:00:00Z'),
    updatedAt: new Date('2026-05-19T00:00:00Z'),
    hidden: false,
    hiddenAt: null,
    hiddenReason: null,
  });
};

// ---------------------------------------------------------------------------
// Fake implementations
// ---------------------------------------------------------------------------

class FakeReportRepository implements ReportRepository {
  private _report: Report | null;
  readonly saved: Report[] = [];

  constructor(report: Report | null = null) {
    this._report = report;
  }

  save(report: Report, _ctx?: TxContext): Promise<void> {
    this.saved.push(report);
    return Promise.resolve();
  }
  findById(_id: string, _ctx?: TxContext): Promise<Report | null> {
    return Promise.resolve(this._report);
  }
  listUnresolved = vi.fn();
  listOlderThan = vi.fn();
  listOpenOlderThan = vi.fn();
  listByReporter = vi.fn();
  deleteAllForUser = vi.fn();
  deleteById = vi.fn();
  findOrphanedOriginatingReportIds = vi.fn();
}

class FakeReviewRepository implements ReviewRepository {
  private _review: Review | null;
  readonly saved: Review[] = [];

  constructor(review: Review | null = null) {
    this._review = review;
  }

  save(review: Review, _ctx?: TxContext): Promise<void> {
    this.saved.push(review);
    return Promise.resolve();
  }
  findById(_id: string, _ctx?: TxContext): Promise<Review | null> {
    return Promise.resolve(this._review);
  }
  findByTriple = vi.fn();
  listByRatedUser = vi.fn();
  listWrittenBy = vi.fn();
  findExistingTriples = vi.fn();
  aggregateForUser = vi.fn();
  deleteAllForUser = vi.fn();
}

class FakeRecordModerationActionUseCase {
  readonly recorded: Array<{ input: RecordModerationActionInput; ctx: TxContext }> = [];
  execute(input: RecordModerationActionInput, ctx: TxContext): Promise<void> {
    this.recorded.push({ input, ctx });
    return Promise.resolve();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('PerformModerationActionUseCase', () => {
  describe('touch action', () => {
    it('sets firstReviewedAt and saves the report on first touch', async () => {
      const report = makeReport();
      const reports = new FakeReportRepository(report);
      const reviews = new FakeReviewRepository();
      const publisher = new FakeEventPublisher();
      const audit = new FakeRecordModerationActionUseCase();
      const clock = new FixedClock(NOW);

      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        reports,
        reviews,
        publisher,
        audit as unknown as RecordModerationActionUseCase,
        clock,
      );

      await useCase.execute({
        operatorUserId: 'op-1',
        action: 'touch',
        reportId: report.id,
        reason: null,
      });

      expect(report.firstReviewedAt).toEqual(NOW);
      expect(reports.saved).toHaveLength(1);
      expect(audit.recorded).toHaveLength(1);
      expect(audit.recorded[0]?.input.action).toBe('touch');
      expect(audit.recorded[0]?.input.reason).toBeNull();
      expect(audit.recorded[0]?.input.contentSnapshot).toBeNull();
    });

    it('is a no-op on second touch (no save, no audit row)', async () => {
      const report = makeReport();
      report.touch(new Date('2026-05-20T08:00:00Z')); // already touched
      const reports = new FakeReportRepository(report);
      const reviews = new FakeReviewRepository();
      const publisher = new FakeEventPublisher();
      const audit = new FakeRecordModerationActionUseCase();
      const clock = new FixedClock(NOW);

      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        reports,
        reviews,
        publisher,
        audit as unknown as RecordModerationActionUseCase,
        clock,
      );

      await useCase.execute({
        operatorUserId: 'op-1',
        action: 'touch',
        reportId: report.id,
        reason: null,
      });

      // firstReviewedAt unchanged (no mutation on already-touched)
      expect(report.firstReviewedAt).toEqual(new Date('2026-05-20T08:00:00Z'));
      expect(reports.saved).toHaveLength(0);
      expect(audit.recorded).toHaveLength(0);
    });

    it('passes the TxContext through to the audit use case', async () => {
      const report = makeReport();
      const capturedCtxValues: TxContext[] = [];
      const auditCapturing = {
        execute(input: RecordModerationActionInput, ctx: TxContext): Promise<void> {
          capturedCtxValues.push(ctx);
          return Promise.resolve();
        },
      };

      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        auditCapturing as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await useCase.execute({
        operatorUserId: 'op-1',
        action: 'touch',
        reportId: report.id,
        reason: null,
      });

      expect(capturedCtxValues).toHaveLength(1);
      expect(capturedCtxValues[0]).toBe(TEST_TX);
    });
  });

  describe('resolve_hidden action', () => {
    it('resolves the report and hides the target review atomically', async () => {
      const report = makeReport('review');
      const review = makeReview('Original comment text');
      const reports = new FakeReportRepository(report);
      // Return the same review for both the pre-snapshot read and the in-tx read
      const reviews = new FakeReviewRepository(review);
      const publisher = new FakeEventPublisher();
      const audit = new FakeRecordModerationActionUseCase();

      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        reports,
        reviews,
        publisher,
        audit as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await useCase.execute({
        operatorUserId: 'op-1',
        action: 'resolve_hidden',
        reportId: report.id,
        reason: 'Violates community guidelines',
      });

      expect(report.isResolved).toBe(true);
      expect(report.resolution).toBe('hidden');
      expect(review.hidden).toBe(true);
      expect(review.hiddenReason).toBe('Violates community guidelines');
      expect(reviews.saved).toHaveLength(1);
      expect(reports.saved).toHaveLength(1);
      // reportResolved event + reviewHidden event both published
      expect(publisher.published.length).toBeGreaterThanOrEqual(2);
      expect(audit.recorded).toHaveLength(1);
      expect(audit.recorded[0]?.input.action).toBe('resolve_hidden');
      expect(audit.recorded[0]?.input.reason).toBe('Violates community guidelines');
      expect(audit.recorded[0]?.input.contentSnapshot).toBe('Original comment text');
    });

    it('snapshot is null when review has no comment', async () => {
      const reviewNoComment = Review.rehydrate({
        id: createId(),
        eventId: createId(),
        raterUserId: createId(),
        ratedUserId: createId(),
        rating: Rating.create(3),
        comment: null,
        createdAt: new Date('2026-05-19T00:00:00Z'),
        updatedAt: new Date('2026-05-19T00:00:00Z'),
        hidden: false,
        hiddenAt: null,
        hiddenReason: null,
      });
      // Set targetId to match the review
      const targetReport = Report.file({
        id: createId(),
        reporterUserId: createId(),
        target: ReportTarget.create('review', reviewNoComment.id),
        reason: ReportReason.create('harassment'),
        comment: null,
        now: new Date('2026-05-20T00:00:00Z'),
      });
      targetReport.pullEvents();

      const audit = new FakeRecordModerationActionUseCase();
      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(targetReport),
        new FakeReviewRepository(reviewNoComment),
        new FakeEventPublisher(),
        audit as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await useCase.execute({
        operatorUserId: 'op-1',
        action: 'resolve_hidden',
        reportId: targetReport.id,
        reason: 'Harassment',
      });

      expect(audit.recorded[0]?.input.contentSnapshot).toBeNull();
    });

    it('is idempotent when target review is already hidden (no double-save)', async () => {
      const report = makeReport('review');
      const alreadyHiddenReview = Review.rehydrate({
        id: createId(),
        eventId: createId(),
        raterUserId: createId(),
        ratedUserId: createId(),
        rating: Rating.create(2),
        comment: ReviewComment.create('some text'),
        createdAt: new Date('2026-05-19T00:00:00Z'),
        updatedAt: new Date('2026-05-19T00:00:00Z'),
        hidden: true,
        hiddenAt: new Date('2026-05-21T00:00:00Z'),
        hiddenReason: 'prior moderation',
      });
      const reviews = new FakeReviewRepository(alreadyHiddenReview);
      const publisher = new FakeEventPublisher();

      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        reviews,
        publisher,
        new FakeRecordModerationActionUseCase() as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await useCase.execute({
        operatorUserId: 'op-1',
        action: 'resolve_hidden',
        reportId: report.id,
        reason: 'Violation',
      });

      // Review was already hidden — hide() was a no-op, so no reviewHidden event
      // and review was NOT re-saved.
      expect(reviews.saved).toHaveLength(0);
      // Report was resolved, so reportResolved event is published
      const publishedTypes = publisher.published.map((e) => e.type);
      expect(publishedTypes).not.toContain('reviews.reviewHidden');
    });

    it('throws 400 when reason is empty', async () => {
      const report = makeReport();
      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        new FakeRecordModerationActionUseCase() as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          action: 'resolve_hidden',
          reportId: report.id,
          reason: '   ',
        }),
      ).rejects.toMatchObject({ status: 400 });
    });

    it('throws 400 when reason is null', async () => {
      const report = makeReport();
      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        new FakeRecordModerationActionUseCase() as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          action: 'resolve_hidden',
          reportId: report.id,
          reason: null,
        }),
      ).rejects.toMatchObject({ status: 400 });
    });
  });

  describe('resolve_kept action', () => {
    it('resolves the report as kept without touching any review', async () => {
      const report = makeReport();
      const reviews = new FakeReviewRepository();
      const publisher = new FakeEventPublisher();
      const audit = new FakeRecordModerationActionUseCase();

      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        reviews,
        publisher,
        audit as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await useCase.execute({
        operatorUserId: 'op-1',
        action: 'resolve_kept',
        reportId: report.id,
        reason: 'Does not violate guidelines',
      });

      expect(report.isResolved).toBe(true);
      expect(report.resolution).toBe('kept');
      expect(reviews.saved).toHaveLength(0); // no review mutation
      expect(audit.recorded).toHaveLength(1);
      expect(audit.recorded[0]?.input.action).toBe('resolve_kept');
      expect(audit.recorded[0]?.input.contentSnapshot).toBeNull();
      expect(audit.recorded[0]?.input.reason).toBe('Does not violate guidelines');
    });
  });

  describe('error branches', () => {
    it('throws 404 when report not found', async () => {
      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(null),
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        new FakeRecordModerationActionUseCase() as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          action: 'touch',
          reportId: createId(),
          reason: null,
        }),
      ).rejects.toMatchObject({ status: 404 });
    });

    it('throws 409 (ReportAlreadyResolved) when resolving an already-resolved report', async () => {
      const report = makeReport();
      report.resolve({ resolution: 'kept', resolvedByUserId: 'op-0', now: new Date() });
      report.pullEvents();

      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        new FakeRecordModerationActionUseCase() as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          action: 'resolve_kept',
          reportId: report.id,
          reason: 'Another reason',
        }),
      ).rejects.toMatchObject({ status: 409 });
    });

    it('throws 409 when resolving an escalated report with no externalInputs and no overrideReason', async () => {
      const report = makeEscalatedReport({ category: 'ambiguous-policy', externalInputCount: 0 });
      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        new FakeRecordModerationActionUseCase() as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          action: 'resolve_kept',
          reportId: report.id,
          reason: 'Does not violate guidelines',
          // overrideReason intentionally omitted — escalationResolveBlocked
        }),
      ).rejects.toMatchObject({ status: 409 });
    });

    it('throws 404 when target review not found during resolve_hidden', async () => {
      const report = makeReport('review');
      // Pre-snapshot read returns a review, but in-tx read returns null
      let callCount = 0;
      const reviewsMissing: Pick<ReviewRepository, 'findById'> & ReviewRepository = {
        findById(_id: string, _ctx?: TxContext): Promise<Review | null> {
          callCount++;
          // First call (pre-snapshot, no ctx) returns a stub review
          // Second call (in-tx, with ctx) returns null to simulate not found
          if (callCount === 1) {
            return Promise.resolve(makeReview());
          }
          return Promise.resolve(null);
        },
        save: vi.fn(),
        findByTriple: vi.fn(),
        listByRatedUser: vi.fn(),
        listWrittenBy: vi.fn(),
        findExistingTriples: vi.fn(),
        aggregateForUser: vi.fn(),
        deleteAllForUser: vi.fn(),
      };

      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        reviewsMissing,
        new FakeEventPublisher(),
        new FakeRecordModerationActionUseCase() as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          action: 'resolve_hidden',
          reportId: report.id,
          reason: 'Violation',
        }),
      ).rejects.toMatchObject({ status: 404 });
    });
  });

  describe('resolve_with_override action (AC5)', () => {
    it('resolves an ambiguous-policy escalated report with overrideReason and writes resolve_with_override audit row', async () => {
      const report = makeEscalatedReport({ category: 'ambiguous-policy', externalInputCount: 0 });
      const reports = new FakeReportRepository(report);
      const audit = new FakeRecordModerationActionUseCase();

      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        reports,
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        audit as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await useCase.execute({
        operatorUserId: 'op-1',
        action: 'resolve_kept',
        reportId: report.id,
        reason: 'Standard resolution reason',
        overrideReason: 'Policy team reviewed; no violation found on balance',
      });

      expect(report.isResolved).toBe(true);
      expect(report.resolution).toBe('kept');
      expect(reports.saved).toHaveLength(1);
      expect(audit.recorded).toHaveLength(1);

      const auditEntry = audit.recorded[0];
      expect(auditEntry).toBeDefined();
      if (!auditEntry) throw new Error('unreachable');
      const auditRow = auditEntry.input;
      expect(auditRow.action).toBe('resolve_with_override');
      // reason carries the overrideReason text, not the standard reason
      expect(auditRow.reason).toBe('Policy team reviewed; no violation found on balance');
      // escalationCategory is carried forward for traceability
      expect(auditRow.escalationCategory).toBe('ambiguous-policy');
      // externalRef/externalSource/etc. remain null for resolve actions
      expect(auditRow.externalRef).toBeUndefined();
    });

    it('resolves an external-jurisdiction escalated report with overrideReason', async () => {
      const report = makeEscalatedReport({
        category: 'external-jurisdiction',
        externalInputCount: 0,
      });
      const audit = new FakeRecordModerationActionUseCase();

      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        audit as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      // Use resolve_kept (not resolve_hidden) so no review-lookup is needed;
      // this test exercises the audit-action branch, not the review-hide path.
      await useCase.execute({
        operatorUserId: 'op-1',
        action: 'resolve_kept',
        reportId: report.id,
        reason: 'Keep the content',
        overrideReason: 'Jurisdiction analysis: no applicable local law',
      });

      expect(report.isResolved).toBe(true);
      const extJurisdEntry = audit.recorded[0];
      expect(extJurisdEntry).toBeDefined();
      if (!extJurisdEntry) throw new Error('unreachable');
      expect(extJurisdEntry.input.action).toBe('resolve_with_override');
      expect(extJurisdEntry.input.escalationCategory).toBe('external-jurisdiction');
    });

    it('resolves an escalated report that already has an external-input row (no override needed) — audit action stays resolve_kept', async () => {
      const report = makeEscalatedReport({ category: 'ambiguous-policy', externalInputCount: 1 });
      const audit = new FakeRecordModerationActionUseCase();

      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        audit as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await useCase.execute({
        operatorUserId: 'op-1',
        action: 'resolve_kept',
        reportId: report.id,
        reason: 'External input received; no violation',
        // overrideReason omitted — external-input satisfies the guard
      });

      expect(report.isResolved).toBe(true);
      const extInputEntry = audit.recorded[0];
      expect(extInputEntry).toBeDefined();
      if (!extInputEntry) throw new Error('unreachable');
      expect(extInputEntry.input.action).toBe('resolve_kept');
      expect(extInputEntry.input.escalationCategory).toBeNull();
    });

    it('throws 400 when overrideReason is supplied on a non-escalated report (domain rejects)', async () => {
      const report = makeReport(); // not escalated
      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        new FakeRecordModerationActionUseCase() as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          action: 'resolve_kept',
          reportId: report.id,
          reason: 'Some reason',
          overrideReason: 'This should be rejected',
        }),
      ).rejects.toMatchObject({ status: 400 });
    });

    it('throws 400 when overrideReason is supplied on a criminal-content escalation (prohibited by domain)', async () => {
      const report = makeEscalatedReport({ category: 'criminal-content', externalInputCount: 0 });
      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        new FakeRecordModerationActionUseCase() as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          action: 'resolve_kept',
          reportId: report.id,
          reason: 'Some reason',
          overrideReason: 'Should not be allowed for criminal-content',
        }),
      ).rejects.toMatchObject({ status: 400 });
    });

    it('throws 400 when overrideReason is supplied on an imminent-harm escalation (prohibited by domain)', async () => {
      const report = makeEscalatedReport({ category: 'imminent-harm', externalInputCount: 0 });
      const useCase = new PerformModerationActionUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        new FakeReviewRepository(),
        new FakeEventPublisher(),
        new FakeRecordModerationActionUseCase() as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          action: 'resolve_kept',
          reportId: report.id,
          reason: 'Some reason',
          overrideReason: 'Should not be allowed for imminent-harm',
        }),
      ).rejects.toMatchObject({ status: 400 });
    });
  });
});
