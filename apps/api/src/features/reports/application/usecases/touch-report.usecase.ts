import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';

export interface TouchReportInput {
  moderatorUserId: string;
  reportId: string;
}

/**
 * Mark a report as first-reviewed by a moderator.
 *
 * Sets `firstReviewedAt` if this is the first touch. Subsequent calls are
 * idempotent — `report.touch()` is a no-op if `firstReviewedAt` is already
 * set, so no second mutation or event is emitted.
 *
 * No HTTP endpoint — invoked from admin CLI (Brief 3B).
 */
export class TouchReportUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly reports: ReportRepository,
    private readonly clock: Clock,
  ) {}

  async execute(input: TouchReportInput): Promise<void> {
    const report = await this.reports.findById(input.reportId);
    if (!report) {
      throw AppError.notFound('Report not found');
    }

    const now = this.clock.now();
    const wasTouched = report.firstReviewedAt !== null;
    report.touch(now);

    // If firstReviewedAt was already set, touch() was a no-op — skip the save.
    if (wasTouched) return;

    await this.unitOfWork.run(async (ctx) => {
      await this.reports.save(report, ctx);
    });
  }
}
