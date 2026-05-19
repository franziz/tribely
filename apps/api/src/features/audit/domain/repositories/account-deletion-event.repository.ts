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
 * Locked at TRI-134. Do NOT extend without a new ticket + legal review.
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
  | 'event_audit_logs_actor_hashed'
  | 'outbox_events_redacted';

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
