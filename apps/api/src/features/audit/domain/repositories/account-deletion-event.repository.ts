import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * Closed enum of account-deletion outcomes.
 * Do NOT extend without a new ticket + legal review (PDPA s24 evidence schema).
 */
export type AccountDeletionOutcome = 'completed' | 'failed_rolled_back';

/**
 * Closed enum of cascade scopes touched during account deletion.
 * Each value represents a class of data that was pseudonymised or deleted.
 *
 * Extended in TRI-155 — three new scopes added for the reviews/reports/user-blocks
 * cascade. No semantic shift in PDPA s24 evidence schema, just additional scope tags.
 *
 * Extended in TRI-217 — support-ticket PDPA cascade scope.
 *
 * NOTE: `event_audit_logs_actor_hashed` was removed in Brief E adjudication.
 * `EventAuditLog` has no `actorUserId` column — it joins to `http_audit_logs`
 * via `requestId`, so audit-actor hashing is fully covered by
 * `http_audit_logs_actor_hashed` alone. The PII cascade contract doc
 * (docs/policy/pii-cascade-contract.md) row 12 is stale; flag for correction.
 */
export type AccountDeletionCascadeScope =
  | 'users'
  | 'credentials'
  | 'refresh_tokens'
  | 'email_verification_tokens'
  | 'password_reset_tokens'
  | 'selfies'
  | 'check_ins'
  | 'events_hosted'
  | 'join_requests_authored'
  | 'http_audit_logs_actor_hashed'
  | 'outbox_events_redacted'
  | 'reports_deleted'
  | 'reviews_deleted'
  | 'user_blocks_deleted'
  | 'support_tickets';

export interface AccountDeletionEventRecord {
  id: string;
  /** SHA-256 hex hash of the userId — non-reversible. No lookup table retained. */
  userIdHash: string;
  requestedAt: Date;
  completedAt: Date;
  requestId: string | null;
  /** Array of cascade scopes applied during this deletion. Stored as TEXT[]. */
  cascadeScope: AccountDeletionCascadeScope[];
  outcome: AccountDeletionOutcome;
  failureReason: string | null;
  recordedAt: Date;
}

/**
 * Append-only by contract. PDPA s24 evidence integrity requires no UPDATE /
 * repair / backfill path. If you find yourself wanting to "fix" a row,
 * STOP — file a new ticket with legal review. Single `record(...)` method
 * by design; no prune method — account-deletion audit rows are retained
 * indefinitely per PDPA s24 evidence requirements.
 *
 * `record` requires a non-optional TxContext: the audit row MUST commit
 * atomically with the triggering account-deletion mutation. "Account deleted
 * but audit row absent" is a legal incident under PDPA s24 evidence integrity.
 * Making `ctx` required turns that atomicity contract into a compile-time
 * property rather than a runbook footnote.
 */
export interface AccountDeletionEventRepository {
  record(entry: AccountDeletionEventRecord, ctx: TxContext): Promise<void>;
}
