import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  HttpAuditLogRecord,
  HttpAuditLogRepository,
} from '../../domain/repositories/http-audit-log.repository.js';

export class HttpAuditLogPrismaRepository implements HttpAuditLogRepository {
  constructor(private readonly db: Db) {}

  async record(entry: HttpAuditLogRecord, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    await client.httpAuditLog.create({
      data: {
        id: entry.id,
        requestId: entry.requestId,
        method: entry.method,
        path: entry.path,
        status: entry.status,
        durationMs: entry.durationMs,
        actorUserId: entry.actorUserId,
        ip: entry.ip,
        userAgent: entry.userAgent,
        errorCode: entry.errorCode,
        receivedAt: entry.receivedAt,
      },
    });
  }
}
