import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import { Report } from '../../domain/entities/report.js';
import { ReportComment } from '../../domain/value-objects/report-comment.js';
import { ReportReason } from '../../domain/value-objects/report-reason.js';
import { ReportTarget } from '../../domain/value-objects/report-target.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import type { TargetResolver } from '../services/target-resolver.js';

export interface FileReportInput {
  reporterUserId: string;
  targetType: string;
  targetId: string;
  reason: string;
  comment?: string;
}

export interface FileReportOutput {
  reportId: string;
}

/**
 * File a new report against a piece of content (initially review only).
 *
 * Rejects with HTTP 422 (`reports.targetTypeNotImplemented`) if the resolver
 * returns `not-implemented` for the given targetType.
 * Rejects with HTTP 404 (`reports.targetNotFound`) if the target entity
 * does not exist.
 *
 * The report is saved and `reports.reportFiled` is published atomically
 * inside a single `unitOfWork.run(...)`.
 */
export class FileReportUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly reports: ReportRepository,
    private readonly resolver: TargetResolver,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: FileReportInput): Promise<FileReportOutput> {
    // Build VOs first so validation throws before any side-effects.
    const target = ReportTarget.create(input.targetType, input.targetId);
    const reason = ReportReason.create(input.reason);
    const comment = ReportComment.create(input.comment ?? null);

    // Resolve the target entity.
    const resolved = await this.resolver.resolve(target.type, target.id);
    if (resolved.kind === 'not-implemented') {
      throw AppError.unprocessable(
        `Target type "${input.targetType}" is not yet supported for reports`,
        { subcode: 'reports.targetTypeNotImplemented' },
      );
    }
    if (resolved.kind === 'not-found') {
      throw AppError.notFound(`Report target not found`, {
        subcode: 'reports.targetNotFound',
      });
    }

    const id = createId();
    const now = this.clock.now();
    const report = Report.file({
      id,
      reporterUserId: input.reporterUserId,
      target,
      reason,
      comment,
      now,
    });

    await this.unitOfWork.run(async (ctx) => {
      await this.reports.save(report, ctx);
      await this.publisher.publish(ctx, ...report.pullEvents());
    });

    return { reportId: id };
  }
}
