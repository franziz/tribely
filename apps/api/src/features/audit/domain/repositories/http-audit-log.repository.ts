/**
 * HttpAuditLog repository interface. The aggregate is intentionally small
 * (an audit row is a value, not an entity with state transitions) so the
 * repository surface is record-only — no findById / save / update.
 */
export interface HttpAuditLogRecord {
  id: string;
  requestId: string;
  method: string;
  path: string;
  status: number;
  durationMs: number;
  actorUserId: string | null;
  ip: string | null;
  userAgent: string | null;
  errorCode: string | null;
  receivedAt: Date;
}

export interface HttpAuditLogRepository {
  record(entry: HttpAuditLogRecord): Promise<void>;
}
