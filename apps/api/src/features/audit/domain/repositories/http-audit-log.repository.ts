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

  /**
   * Replace all `actorUserId` values that equal `userId` with `actorHash`
   * (a deterministic one-way hash of the original id).
   *
   * Called as part of the PDPA account-deletion cascade. The caller (Brief E
   * DeleteAccountUseCase) supplies `actorHash = sha256Hex(userId)`, which is
   * the SAME value written to `account_deletion_events.userIdHash`, so the
   * forensic cross-table join remains intact without retaining plaintext PII.
   *
   * Returns the number of rows updated.
   */
  hashActorForUser(userId: string, actorHash: string, ctx: TxContext): Promise<number>;
}
