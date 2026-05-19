import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { UserBlock } from '../entities/user-block.js';

/**
 * Repository for the UserBlock aggregate.
 *
 * Block checks are BIDIRECTIONAL: A blocks B and B blocks A are treated
 * symmetrically in `findBidirectional` and `filterBlocked`.
 */
export interface UserBlockRepository {
  save(block: UserBlock, ctx?: TxContext): Promise<void>;

  /**
   * Delete a block row by (initiatorUserId, blockedUserId). Used after
   * `block.initiateUnblock()` — the use case calls this to persist the
   * deletion after pulling events.
   *
   * No-op if the row doesn't exist (supports idempotent unblock).
   */
  delete(input: { initiatorUserId: string; blockedUserId: string }, ctx?: TxContext): Promise<void>;

  /**
   * Find a block by exact direction: A blocked B (not the reverse).
   */
  findOne(
    input: { initiatorUserId: string; blockedUserId: string },
    ctx?: TxContext,
  ): Promise<UserBlock | null>;

  /**
   * Find a block in EITHER direction between userA and userB.
   *
   * Returns the block row if A→B OR B→A exists; null otherwise.
   * Used by `CheckBlockedPort.isBlocked`.
   */
  findBidirectional(
    input: { userA: string; userB: string },
    ctx?: TxContext,
  ): Promise<UserBlock | null>;

  /**
   * Return the subset of `candidateIds` that have a block relationship
   * (in EITHER direction) with `viewerId`.
   *
   * Efficient bulk check — avoids N individual queries. Used by
   * `CheckBlockedPort.filterBlocked` for list-view filtering.
   */
  filterBlocked(
    input: { viewerId: string; candidateIds: string[] },
    ctx?: TxContext,
  ): Promise<Set<string>>;

  /**
   * Cursor-paginated listing of blocks initiated by `initiatorUserId`.
   * Ordered by `createdAt DESC, id DESC` (newest first).
   */
  listInitiatedBy(
    input: {
      initiatorUserId: string;
      cursor?: string;
      limit: number;
    },
    ctx?: TxContext,
  ): Promise<{ rows: UserBlock[]; nextCursor: string | null }>;
}
