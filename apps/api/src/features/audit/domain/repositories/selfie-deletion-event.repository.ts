import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * Closed enum of deletion reasons at launch (CEO + legal locked 2026-05-19).
 * Do NOT extend without a new ticket + legal review.
 */
export type SelfieDeletionReason =
  | 'retention-sweep'
  | 'account-deletion'
  | 'user-request'
  | 'reviewer-rejection-aged';

export interface SelfieDeletionEventRecord {
  id: string;
  userId: string;
  selfieId: string;
  reason: SelfieDeletionReason;
  deletedAt: Date;
  requestId: string | null;
  recordedAt: Date;
}

/**
 * Append-only by contract. PDPA s25 evidence integrity requires no UPDATE /
 * repair / backfill path. If you find yourself wanting to "fix" a row,
 * STOP — file a new ticket with legal review. Single `record(...)` method
 * by design; `pruneOlderThan(...)` is the only legal-sanctioned removal,
 * driven by the 24-month retention sweep.
 */
export interface SelfieDeletionEventRepository {
  record(entry: SelfieDeletionEventRecord, ctx: TxContext): Promise<void>;
  pruneOlderThan(cutoff: Date, ctx: TxContext): Promise<number>;
}
