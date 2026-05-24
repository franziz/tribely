import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { CascadeOnUserDeletionPort } from '../ports/cascade-on-user-deletion.port.js';
import type { UserBlockRepository } from '../../domain/repositories/user-block.repository.js';

export interface CascadeUserBlocksOnUserDeletionInput {
  userId: string;
}

/**
 * Bulk-delete all block rows tied to a user as part of a PDPA erasure
 * cascade. Removes rows where the user is either the initiator OR the
 * blocked party.
 *
 * Required-ctx two-arg execute(input, ctx) shape (A7 exception):
 *   - This use case joins the CALLER's UnitOfWork transaction.
 *   - There is NO internal unitOfWork.run — opening a nested UoW here would
 *     defeat the atomicity contract required by the cascade.
 *   - The repo call commits atomically within the caller-supplied TxContext.
 */
export class CascadeUserBlocksOnUserDeletionUseCase implements CascadeOnUserDeletionPort {
  constructor(private readonly userBlocks: UserBlockRepository) {}

  async execute(input: CascadeUserBlocksOnUserDeletionInput, ctx: TxContext): Promise<void> {
    await this.userBlocks.deleteAllForUser(input.userId, ctx);
  }
}
