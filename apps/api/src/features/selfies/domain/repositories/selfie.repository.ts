import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Selfie } from '../entities/selfie.js';

export interface SelfieRepository {
  /**
   * Persist a Selfie aggregate (insert or update).
   * Must be called inside a UnitOfWork transaction that also publishes
   * the aggregate's events atomically.
   */
  save(selfie: Selfie, ctx?: TxContext): Promise<void>;

  /**
   * Returns the most recent non-deleted selfie for a user, or null if none.
   * "Active" means status ∈ {pending, approved, rejected}.
   */
  findActiveByUserId(userId: string, ctx?: TxContext): Promise<Selfie | null>;

  /**
   * Returns selfies eligible for the PDPA retention sweep:
   *   - status = 'approved' AND approvedAt < cutoff, OR
   *   - status = 'rejected' AND rejectedAt < cutoff
   *
   * Excludes `pending` (no terminal timestamp yet) and `deleted` (already
   * processed). Used by the retention sweep job (Brief 2/3).
   */
  findEligibleForRetentionSweep(cutoff: Date, ctx?: TxContext): Promise<Selfie[]>;
}
