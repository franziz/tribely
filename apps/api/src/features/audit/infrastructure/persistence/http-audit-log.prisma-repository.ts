import type { Db } from '@/core/db/prisma.js';
import type {
  HttpAuditLogRecord,
  HttpAuditLogRepository,
} from '../../domain/repositories/http-audit-log.repository.js';

export class HttpAuditLogPrismaRepository implements HttpAuditLogRepository {
  constructor(private readonly db: Db) {}

  async record(entry: HttpAuditLogRecord): Promise<void> {
    await this.db.httpAuditLog.create({
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
