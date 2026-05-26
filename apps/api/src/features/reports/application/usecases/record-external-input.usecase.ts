import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { RecordModerationActionUseCase } from '@/features/audit/application/usecases/record-moderation-action.usecase.js';
import type { ExternalInputSource } from '@/features/audit/domain/types/moderation-action.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';

export interface RecordExternalInputInput {
  operatorUserId: string;
  reportId: string;
  source: ExternalInputSource; // counsel | partner | imda | other
  disposition: string; // operator-supplied; non-empty required
  receivedAt: Date; // operator-supplied ISO8601
}

/**
 * Records an external input (counsel/partner/regulator communication) against
 * an escalated report as an append-only audit row.
 *
 * Does NOT mutate the Report aggregate — the external-input count is derived
 * from audit rows via `countExternalInputs` (Brief C). No aggregate event is
 * emitted. The UnitOfWork wrapping is for atomicity of the audit-row write only.
 *
 * Append-only by design: multiple external-input rows for the same report are
 * explicitly allowed (no idempotency key). No edit or delete surface.
 *
 * Pre-conditions:
 *   - Report must exist.
 *   - Report must be escalated (`report.isEscalated === true`).
 *   - Report must not already be resolved.
 *   - `disposition` must be non-empty (after trim).
 *
 * DI wiring deferred to Brief G.
 */
export class RecordExternalInputUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly reports: ReportRepository,
    private readonly recordAudit: RecordModerationActionUseCase,
    private readonly clock: Clock,
  ) {}

  async execute(input: RecordExternalInputInput): Promise<void> {
    if (input.disposition.trim().length === 0) {
      throw AppError.validation('Disposition required', {
        subcode: 'reports.dispositionRequired',
      });
    }

    const now = this.clock.now();
    const report = await this.reports.findById(input.reportId);
    if (!report) throw AppError.notFound('Report not found');

    if (!report.isEscalated) {
      throw AppError.conflict('Report is not escalated; cannot record external input', {
        subcode: 'reports.notEscalated',
      });
    }
    if (report.isResolved) {
      throw AppError.conflict('Report already resolved', {
        subcode: 'reports.reportAlreadyResolved',
      });
    }

    await this.unitOfWork.run(async (ctx) => {
      await this.recordAudit.execute(
        {
          operatorUserId: input.operatorUserId,
          action: 'record_external_input',
          reportId: report.id,
          targetType: report.target.type,
          targetId: report.target.id,
          reason: null,
          contentSnapshot: null,
          reporterUserId: report.reporterUserId,
          reasonCode: null,
          justificationText: null,
          originatingReportId: null,
          escalationCategory: report.escalationCategory, // carry forward
          externalRef: null,
          externalSource: input.source,
          externalDisposition: input.disposition,
          externalReceivedAt: input.receivedAt,
          actedAt: now,
        },
        ctx,
      );
    });
  }
}
