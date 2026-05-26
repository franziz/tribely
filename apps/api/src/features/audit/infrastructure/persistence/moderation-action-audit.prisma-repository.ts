import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  ModerationActionAuditRecord,
  ModerationActionAuditRepository,
} from '../../domain/repositories/moderation-action-audit.repository.js';

export class ModerationActionAuditPrismaRepository implements ModerationActionAuditRepository {
  constructor(private readonly db: Db) {}

  async record(entry: ModerationActionAuditRecord, ctx: TxContext): Promise<void> {
    const client = unwrapTx(ctx);
    await client.moderationActionAudit.create({
      data: {
        id: entry.id,
        operatorUserId: entry.operatorUserId,
        action: entry.action,
        reportId: entry.reportId,
        targetType: entry.targetType,
        targetId: entry.targetId,
        reason: entry.reason,
        contentSnapshot: entry.contentSnapshot,
        reporterUserId: entry.reporterUserId,
        reasonCode: entry.reasonCode,
        justificationText: entry.justificationText,
        originatingReportId: entry.originatingReportId,
        escalationCategory: entry.escalationCategory,
        externalRef: entry.externalRef,
        externalSource: entry.externalSource,
        externalDisposition: entry.externalDisposition,
        externalReceivedAt: entry.externalReceivedAt,
        actedAt: entry.actedAt,
        requestId: entry.requestId,
        recordedAt: entry.recordedAt,
      },
    });
  }

  async severOriginatingReportId(reportId: string, ctx: TxContext): Promise<number> {
    const client = unwrapTx(ctx);
    const result = await client.moderationActionAudit.updateMany({
      where: { originatingReportId: reportId },
      data: { originatingReportId: null },
    });
    return result.count;
  }

  async countExternalInputs(reportId: string, ctx?: TxContext): Promise<number> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    return client.moderationActionAudit.count({
      where: { reportId, action: 'record_external_input' },
    });
  }
}
