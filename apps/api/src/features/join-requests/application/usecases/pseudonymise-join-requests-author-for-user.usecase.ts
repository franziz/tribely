import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { JoinRequestRepository } from '../../domain/repositories/join-request.repository.js';

export interface PseudonymiseJoinRequestsAuthorForUserInput {
  userId: string;
  pseudonymAuthorId: string;
}

export interface PseudonymiseJoinRequestsAuthorForUserResult {
  updatedCount: number;
}

/**
 * Pseudonymise all join-request rows authored by a user as part of a PDPA
 * erasure cascade. Rewrites `requesterUserId` to an opaque cuid2 pseudonym
 * supplied by the caller.
 *
 * "Author" is the domain term used in Brief E's contract; the underlying
 * schema column is `requesterUserId` (the original naming from the join-
 * requests bounded context). The use case surfaces the domain term;
 * the repository method maps it to the actual column.
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
export class PseudonymiseJoinRequestsAuthorForUserUseCase {
  constructor(private readonly joinRequests: JoinRequestRepository) {}

  async execute(
    input: PseudonymiseJoinRequestsAuthorForUserInput,
    ctx: TxContext,
  ): Promise<PseudonymiseJoinRequestsAuthorForUserResult> {
    const updatedCount = await this.joinRequests.pseudonymiseAuthorForUser(
      input.userId,
      input.pseudonymAuthorId,
      ctx,
    );
    return { updatedCount };
  }
}
