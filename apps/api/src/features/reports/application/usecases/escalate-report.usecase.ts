import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import type { EscalationCategory } from '@/features/audit/domain/types/moderation-action.js';
import type { RecordModerationActionUseCase } from '@/features/audit/application/usecases/record-moderation-action.usecase.js';

export interface EscalateReportInput {
  operatorUserId: string;
  reportId: string;
  category: EscalationCategory;
  externalRef: string;
  note: string | null; // operator free-text; recorded in audit `reason` field
}

/**
 * Escalates a moderation report to an external authority (law enforcement,
 * platform safety team, etc.).
 *
 * Atomicity contract: `reports.save`, `publisher.publish`, and
 * `recordAudit.execute` MUST commit in the same `unitOfWork.run` closure.
 * Audit-row-without-state-transition (or vice versa) is the PDPA-incident
 * bug class this design prevents.
 *
 * This is a distinct use case from PerformModerationActionUseCase — one
 * use case per intent (see CLAUDE.md "One use case per intent").
 */
export class EscalateReportUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly reports: ReportRepository,
    private readonly publisher: EventPublisher,
    private readonly recordAudit: RecordModerationActionUseCase,
    private readonly clock: Clock,
  ) {}

  async execute(input: EscalateReportInput): Promise<void> {
    if (input.externalRef.trim().length === 0) {
      throw AppError.validation('External reference required', {
        subcode: 'reports.externalRefRequired',
      });
    }
    const now = this.clock.now();
    const report = await this.reports.findById(input.reportId);
    if (!report) throw AppError.notFound('Report not found');

    report.escalate({
      category: input.category,
      externalRef: input.externalRef,
      escalatedByUserId: input.operatorUserId,
      now,
    });
    const events = report.pullEvents();

    await this.unitOfWork.run(async (ctx) => {
      await this.reports.save(report, ctx);
      if (events.length > 0) await this.publisher.publish(ctx, ...events);
      await this.recordAudit.execute(
        {
          operatorUserId: input.operatorUserId,
          action: 'escalate',
          reportId: report.id,
          targetType: report.target.type,
          targetId: report.target.id,
          reason: input.note,
          contentSnapshot: null,
          reporterUserId: report.reporterUserId,
          reasonCode: null,
          justificationText: null,
          originatingReportId: null,
          escalationCategory: input.category,
          externalRef: input.externalRef,
          externalSource: null,
          externalDisposition: null,
          externalReceivedAt: null,
          actedAt: now,
        },
        ctx,
      );
    });
  }
}
