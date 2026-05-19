import type { Context } from 'hono';
import type { FileReportUseCase } from '../../../application/usecases/file-report.usecase.js';
import type { FileReportBody } from '../schemas/report.schemas.js';

export class ReportController {
  constructor(private readonly fileReport: FileReportUseCase) {}

  /**
   * POST /reports
   * File a new report against a piece of content.
   */
  fileAction = async (c: Context, actorUserId: string, body: FileReportBody) => {
    const result = await this.fileReport.execute({
      reporterUserId: actorUserId,
      targetType: body.targetType,
      targetId: body.targetId,
      reason: body.reason,
      ...(body.comment !== undefined && { comment: body.comment }),
    });

    return c.json(
      {
        report: {
          id: result.reportId,
          targetType: body.targetType,
          targetId: body.targetId,
          reason: body.reason,
        },
      },
      201,
    );
  };
}
