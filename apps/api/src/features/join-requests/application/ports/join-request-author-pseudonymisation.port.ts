import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * Port describing the pseudonymisation operation for join requests authored
 * by a user.
 *
 * "Author" is the domain term used in Brief E's contract; the underlying
 * schema column is `requesterUserId` (the original naming from the join-
 * requests bounded context). The port and use case surface the domain term;
 * the repository method maps it to the actual column.
 *
 * Two-arg `execute(input, ctx)` signals the A7 exception: callers MUST be
 * inside their own `unitOfWork.run` and pass the TxContext so the rewrite
 * commits atomically with the rest of the deletion cascade.
 *
 * Placing the port in `join-requests/application/ports/` per the A11 rule:
 * application ports describe the structural shape of another feature's
 * application service; they are the sanctioned cross-feature import surface
 * for use-case-shaped operations.
 */
export interface JoinRequestAuthorPseudonymisationPort {
  execute(
    input: {
      userId: string;
      pseudonymAuthorId: string;
    },
    ctx: TxContext,
  ): Promise<{ updatedCount: number }>;
}
