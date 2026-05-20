import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';
import type {
  PseudonymiseEventsHostForUserInput,
  PseudonymiseEventsHostForUserResult,
} from '../dto/pseudonymise-events-host-for-user.dto.js';

export type { PseudonymiseEventsHostForUserInput, PseudonymiseEventsHostForUserResult };

/**
 * Pseudonymise all events hosted by a user as part of a PDPA erasure cascade.
 * Rewrites `hostUserId` to an opaque cuid2 pseudonym supplied by the caller.
 *
 * Required-ctx two-arg execute(input, ctx) shape (A7 exception):
 *   - This use case joins the CALLER's UnitOfWork transaction.
 *   - There is NO internal unitOfWork.run — opening a nested UoW here would
 *     defeat the atomicity contract required by the cascade.
 *   - The repo call commits atomically within the caller-supplied TxContext.
 *
 * The pseudonym is generated ONCE per cascade attempt by the caller (Brief E)
 * and passed in — this use case does NOT generate it. No plaintext-to-pseudonym
 * lookup table is retained (irreversible by design).
 */
export class PseudonymiseEventsHostForUserUseCase {
  constructor(private readonly events: EventRepository) {}

  async execute(
    input: PseudonymiseEventsHostForUserInput,
    ctx: TxContext,
  ): Promise<PseudonymiseEventsHostForUserResult> {
    const updatedCount = await this.events.pseudonymiseHostForUser(
      input.userId,
      input.pseudonymHostId,
      ctx,
    );
    return { updatedCount };
  }
}
