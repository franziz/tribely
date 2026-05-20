import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * Port for cascading join-request cancellations when a block is placed.
 *
 * The concrete implementation lives in `join-requests/application/adapters/`
 * because it touches join-request persistence directly. `user-blocks` imports
 * this interface (allowed: cross-feature application-port import per CLAUDE.md).
 *
 * Cancellation is bidirectional: pending/approved future join requests in
 * EITHER direction between userA and userB are cancelled.
 */
export interface CascadePendingBlocksPort {
  /**
   * Cancel all pending or approved future join requests between `userA` and
   * `userB` (in either direction). Sets status='cancelled' and
   * decisionReason='blocked'. Publishes a `joinRequests.cancelledBySystem`
   * event per cancelled row.
   *
   * Must be called inside a transaction (the block save and cascade must be
   * atomic).
   *
   * @returns The number of rows cancelled.
   */
  cancelPendingAndFutureAcceptedBetween(
    input: { userA: string; userB: string },
    ctx: TxContext,
  ): Promise<{ cancelledCount: number }>;
}
