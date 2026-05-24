import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import type { ReviewRepository } from '@/features/reviews/domain/repositories/review.repository.js';
import type { RecordModerationActionUseCase } from '@/features/audit/application/usecases/record-moderation-action.usecase.js';
import type { ModerationAction } from '@/features/audit/domain/types/moderation-action.js';

export interface PerformModerationActionInput {
  operatorUserId: string;
  action: ModerationAction;
  reportId: string;
  reason: string | null; // required for resolve_*; null for touch
}

/**
 * CLI-only orchestrator that performs a moderation action AND records the
 * audit row in ONE wrapping UnitOfWork.
 *
 * Intentionally bypasses TouchReportUseCase / ResolveReportUseCase (which each
 * own their own UoW) because we need the audit-row insert in the same tx as
 * the state transition (PDPA s24 evidence integrity).
 *
 * Retirement trigger: TRI-159 retires this CLI; at that point either delete
 * TouchReportUseCase / ResolveReportUseCase or refactor them to accept ctx.
 * See TRI-141 EL ruling C.
 *
 * EL-ruled A7 documented exception: the inline Review.hide() + save + publish
 * sequence is the standard aggregate-records-event pattern, just invoked from
 * the CLI orchestrator's wrapping UoW instead of HideReviewUseCase's own UoW.
 */
export class PerformModerationActionUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly reports: ReportRepository,
    private readonly reviews: ReviewRepository,
    private readonly publisher: EventPublisher,
    private readonly recordAudit: RecordModerationActionUseCase,
    private readonly clock: Clock,
  ) {}

  async execute(input: PerformModerationActionInput): Promise<void> {
    if (input.action !== 'touch' && (!input.reason || input.reason.trim().length === 0)) {
      throw AppError.validation('Reason required for resolve_* actions');
    }

    const now = this.clock.now();
    const report = await this.reports.findById(input.reportId);
    if (!report) throw AppError.notFound('Report not found');

    // Capture content snapshot BEFORE state transition for hide flows.
    let contentSnapshot: string | null = null;
    if (input.action === 'resolve_hidden' && report.target.type === 'review') {
      const review = await this.reviews.findById(report.target.id);
      contentSnapshot = review?.comment?.value ?? null;
    }
    // For touch + resolve_kept, snapshot is null by design.

    // Apply state transitions on the aggregate(s).
    const wasTouched = report.firstReviewedAt !== null;
    if (input.action === 'touch') {
      report.touch(now);
      // Touch is event-free per Report aggregate.
    } else {
      // Throws ReportAlreadyResolved if already resolved (append-only invariant).
      report.resolve({
        resolution: input.action === 'resolve_hidden' ? 'hidden' : 'kept',
        resolvedByUserId: input.operatorUserId,
        now,
      });
    }

    const reportEvents = report.pullEvents();
    const isTouchNoOp = input.action === 'touch' && wasTouched;

    await this.unitOfWork.run(async (ctx) => {
      // 1. Save report state transition (skip save for no-op touch).
      if (!isTouchNoOp) {
        await this.reports.save(report, ctx);
      }

      // 2. If hiding a review, perform Review.hide + save + publish on same ctx.
      // Reimplements HideReviewUseCase.execute body inline because we need the
      // SAME ctx (HideReviewUseCase opens its own UoW). EL ruling B/C.
      if (input.action === 'resolve_hidden' && report.target.type === 'review') {
        const review = await this.reviews.findById(report.target.id, ctx);
        if (!review) throw AppError.notFound('Target review not found');
        review.hide({
          hiddenByUserId: input.operatorUserId,
          reportId: input.reportId,
          reason: input.reason ?? '',
          now,
        });
        const reviewEvents = review.pullEvents();
        if (reviewEvents.length > 0) {
          await this.reviews.save(review, ctx);
          await this.publisher.publish(ctx, ...reviewEvents);
        }
        // If reviewEvents.length === 0, the review was already hidden —
        // idempotent no-op (consistent with HideReviewUseCase semantics).
      }

      // 3. Publish report events on same ctx.
      if (reportEvents.length > 0) {
        await this.publisher.publish(ctx, ...reportEvents);
      }

      // 4. Record audit row on same ctx (REQUIRED — atomic with all above).
      // Skip audit on touch no-op (no state change → no audit row).
      if (!isTouchNoOp) {
        await this.recordAudit.execute(
          {
            operatorUserId: input.operatorUserId,
            action: input.action,
            reportId: report.id,
            targetType: report.target.type,
            targetId: report.target.id,
            reason: input.reason,
            contentSnapshot,
            reporterUserId: report.reporterUserId,
            actedAt: now,
          },
          ctx,
        );
      }
    });
  }
}
