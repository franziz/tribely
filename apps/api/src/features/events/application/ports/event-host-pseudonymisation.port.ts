import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * Port describing the pseudonymisation operation for events hosted by a user.
 *
 * Matches the structural shape of `PseudonymiseEventsHostForUserUseCase.execute`
 * — two-arg `execute(input, ctx)` signals the A7 exception: callers MUST be
 * inside their own `unitOfWork.run` and pass the TxContext so the rewrite
 * commits atomically with the rest of the deletion cascade.
 *
 * Placing the port in `events/application/ports/` per the A11 rule:
 * application ports describe the structural shape of another feature's
 * application service; they are the sanctioned cross-feature import surface
 * for use-case-shaped operations.
 */
export interface EventHostPseudonymisationPort {
  execute(
    input: {
      userId: string;
      pseudonymHostId: string;
    },
    ctx: TxContext,
  ): Promise<{ updatedCount: number }>;
}
