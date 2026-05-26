import { createId } from '@paralleldrive/cuid2';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { ModerationActionAuditRepository } from '@/features/audit/domain/repositories/moderation-action-audit.repository.js';
import type { SweepRunRepository } from '@/features/selfies/domain/repositories/sweep-run.repository.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import type { SweepResolvedReportsResult } from '../dto/sweep-resolved-reports.result.js';

const RETENTION_MONTHS = 12;

/**
 * Subtracts `months` calendar months from `date`.
 *
 * Clamps the day to the last valid day of the resulting month (e.g.
 * 2028-03-31 minus 1 month → 2028-02-29, not the invalid 2028-02-31).
 * Mirrors the same helper in PrunePostEventCheckInsUseCase — kept local
 * here to avoid a cross-use-case import (4th duplication; extract at 5th
 * or on a cross-stack lib request).
 */
function subtractMonths(date: Date, months: number): Date {
  const result = new Date(date);
  const targetMonth = result.getMonth() - months;
  result.setMonth(targetMonth);
  const intendedMonth = ((targetMonth % 12) + 12) % 12;
  if (result.getMonth() !== intendedMonth) {
    result.setDate(0);
  }
  return result;
}

/**
 * PDPA-mandated report retention sweep.
 *
 * Finds resolved `moderation_reports` older than 12 months and, for each:
 *   1. NULLs all `moderation_action_audit.originatingReportId` references
 *      (PDPA s25 cross-reference minimisation).
 *   2. Deletes the report row.
 * Steps 1 and 2 are committed atomically in the same per-report transaction
 * (AC3: all-or-nothing per report).
 *
 * After the main pass, runs a defensive orphan-reference pass: finds audit
 * rows whose `originatingReportId` points at a non-existent report row (e.g.,
 * left by a prior partial failure) and NULLs them, logging WARN per orphan.
 *
 * One `sweep_runs` row is written per tick regardless of whether any reports
 * were eligible, providing the regulator audit trail for "did the sweep run
 * on date X?".
 *
 * Does NOT emit domain events — retention-driven mutations follow the selfie
 * sweep precedent of no event emission.
 */
export class SweepResolvedReportsUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly reports: ReportRepository,
    private readonly auditRepo: ModerationActionAuditRepository,
    private readonly sweepRunRepository: SweepRunRepository,
    private readonly clock: Clock,
    private readonly logger: Logger,
  ) {}

  async execute(): Promise<SweepResolvedReportsResult> {
    const startedAt = this.clock.now();
    const startMs = Date.now();
    const cutoff = subtractMonths(startedAt, RETENTION_MONTHS);

    let evaluated = 0;
    let deleted = 0;
    let failed = 0;
    let auditRowsSevered = 0;
    let orphanRowsSevered = 0;

    // --- main pass ---
    const resolvedOldReports = await this.reports.listOlderThan({ resolvedAtBefore: cutoff });
    evaluated = resolvedOldReports.length;

    for (const report of resolvedOldReports) {
      try {
        await this.unitOfWork.run(async (ctx) => {
          const severedThisReport = await this.auditRepo.severOriginatingReportId(report.id, ctx);
          await this.reports.deleteById(report.id, ctx);
          auditRowsSevered += severedThisReport;
        });
        deleted++;
      } catch (err) {
        failed++;
        this.logger.warn({ reportId: report.id, err }, 'Report retention sweep: record failed');
      }
    }

    // --- orphan-reference defensive pass ---
    const orphanReportIds = await this.reports.findOrphanedOriginatingReportIds();
    for (const orphanReportId of orphanReportIds) {
      try {
        await this.unitOfWork.run(async (ctx) => {
          const severed = await this.auditRepo.severOriginatingReportId(orphanReportId, ctx);
          orphanRowsSevered += severed;
          this.logger.warn(
            { orphanReportId, severed },
            'Report retention sweep: severed orphan audit reference (no source report)',
          );
        });
      } catch (err) {
        this.logger.warn(
          { orphanReportId, err },
          'Report retention sweep: orphan severance failed',
        );
      }
    }

    // --- sweep_runs row (one per tick, even on zero-eligible) ---
    await this.sweepRunRepository.record({
      id: createId(),
      kind: 'report-retention-sweep',
      startedAt,
      finishedAt: this.clock.now(),
      evaluated,
      deleted,
      failed,
      reaperRetried: 0,
      reaperSucceeded: 0,
      auditRowsSevered: auditRowsSevered + orphanRowsSevered,
      error: null,
    });

    return {
      evaluated,
      deleted,
      failed,
      auditRowsSevered,
      orphanRowsSevered,
      durationMs: Date.now() - startMs,
    };
  }
}
