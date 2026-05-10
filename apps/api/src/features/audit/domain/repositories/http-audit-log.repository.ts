import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * HttpAuditLog repository interface. The aggregate is intentionally small
 * (an audit row is a value, not an entity with state transitions) so the
 * repository surface is record-only — no findById / save / update.
 *
 * `ctx?: TxContext` follows the repository convention even though the only
 * caller today (the audit-http middleware running after `next()` resolves)
 * never supplies one — the audit row is unitary, no shared transaction.
 * The optional ctx is here for future callers (e.g. an admin bulk action
 * that wants the audit row atomic with a domain mutation).
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
  record(entry: HttpAuditLogRecord, ctx?: TxContext): Promise<void>;
}
