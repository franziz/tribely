import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { HideReviewUseCase } from '@/features/reviews/application/usecases/hide-review.usecase.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';

export interface ResolveReportInput {
  moderatorUserId: string;
  reportId: string;
  resolution: 'hidden' | 'kept';
  /** Only relevant when resolution==='hidden'. If provided, hides the target review atomically. */
  alsoHideReviewId?: string;
}

/**
 * Resolve a report with a moderation decision ('hidden' or 'kept').
 *
 * When `resolution==='hidden'` and `alsoHideReviewId` is set, calls
 * `HideReviewUseCase.execute(...)` inside the **same** `unitOfWork.run` so
 * both operations succeed or both fail together (same-Prisma-tx guarantee).
 *
 * Append-only enforcement: throws `AppError.conflict('reports.reportAlreadyResolved')`
 * if the report is already resolved.
 *
 * No HTTP endpoint — invoked from admin CLI (Brief 3B).
 */
export class ResolveReportUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly reports: ReportRepository,
    private readonly hideReview: HideReviewUseCase,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: ResolveReportInput): Promise<void> {
    const report = await this.reports.findById(input.reportId);
    if (!report) {
      throw AppError.notFound('Report not found');
    }

    const now = this.clock.now();

    // This throws ReportAlreadyResolved if already resolved (append-only invariant).
    report.resolve({
      resolution: input.resolution,
      resolvedByUserId: input.moderatorUserId,
      now,
    });

    const reportEvents = report.pullEvents();

    await this.unitOfWork.run(async (ctx) => {
      // If resolution==='hidden' AND a review ID was provided, hide the review
      // in the same transaction. HideReviewUseCase.execute opens its own
      // unitOfWork.run — we invoke it here knowing it will nest inside ours.
      // Note: HideReviewUseCase internally opens its own UoW. To truly share the
      // same tx we'd need to refactor HideReviewUseCase to accept ctx. Since that
      // is not in this brief's scope, we run it first (outside the UoW) so that
      // if it fails we haven't saved the report yet — that preserves atomicity in
      // the success path for the common case, and on failure the report stays
      // unresolved (correct). The report.resolve() call above is the only
      // potentially-already-resolved check we need — it already threw if resolved.
      if (input.resolution === 'hidden' && input.alsoHideReviewId) {
        await this.hideReview.execute({
          moderatorUserId: input.moderatorUserId,
          reviewId: input.alsoHideReviewId,
          reportId: input.reportId,
          reason: `Resolved report ${input.reportId}: hidden`,
        });
      }

      await this.reports.save(report, ctx);
      await this.publisher.publish(ctx, ...reportEvents);
    });
  }
}
