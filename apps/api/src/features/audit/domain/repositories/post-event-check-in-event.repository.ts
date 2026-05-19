import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * Closed enum of check-in lifecycle reasons at launch.
 * Do NOT extend without a new ticket + legal review — mirrors the CHECK
 * constraint in migration `add_post_event_check_in_events`.
 */
export type PostEventCheckInReason =
  | 'created'
  | 'acknowledged'
  | 'flagged'
  | 'pseudonymised'
  | 'deleted_by_retention';

export interface PostEventCheckInEventEntry {
  id: string;
  checkInId: string;
  userId: string;
  eventId: string;
  reason: PostEventCheckInReason;
  occurredAt: Date;
  requestId: string | null;
  recordedAt: Date;
}

/**
 * Append-only by contract. PDPA s25 evidence integrity requires no UPDATE /
 * repair / backfill path. If you find yourself wanting to "fix" a row,
 * STOP — file a new ticket with legal review.
 *
 * `record(...)` requires a non-optional TxContext so the audit row commits
 * atomically with the triggering domain mutation (A7 exception — see CLAUDE.md).
 *
 * `pruneOlderThan(...)` is the only legal-sanctioned removal, driven by the
 * 24-month retention sweep from `occurredAt`.
 *
 * No public-port read methods — auditor access is out-of-band SQL only.
 */
export interface PostEventCheckInEventRepository {
  record(entry: PostEventCheckInEventEntry, ctx: TxContext): Promise<void>;
  pruneOlderThan(cutoff: Date, ctx: TxContext): Promise<number>;
}
