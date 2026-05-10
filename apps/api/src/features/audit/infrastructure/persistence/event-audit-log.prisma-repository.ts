import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  EventAuditLogRecord,
  EventAuditLogRepository,
} from '../../domain/repositories/event-audit-log.repository.js';

export class EventAuditLogPrismaRepository implements EventAuditLogRepository {
  constructor(private readonly db: Db) {}

  async record(entries: EventAuditLogRecord[], ctx?: TxContext): Promise<void> {
    if (entries.length === 0) return;
    const client = ctx ? unwrapTx(ctx) : this.db;
    await client.eventAuditLog.createMany({
      data: entries.map((e) => ({
        id: e.id,
        requestId: e.requestId,
        eventSeq: e.eventSeq,
        eventType: e.eventType,
        consumerName: e.consumerName,
        phase: e.phase,
        attempt: e.attempt,
        errorMessage: e.errorMessage,
        recordedAt: e.recordedAt,
      })),
    });
  }
}
