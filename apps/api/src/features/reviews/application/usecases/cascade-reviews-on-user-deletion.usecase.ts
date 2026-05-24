import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { CascadeOnUserDeletionPort } from '../ports/cascade-on-user-deletion.port.js';
import type { ReviewRepository } from '../../domain/repositories/review.repository.js';

/**
 * Bulk-delete all reviews authored by or about a user as part of a PDPA
 * erasure cascade on account deletion.
 *
 * Required-ctx two-arg execute(input, ctx) shape (A7 exception):
 *   - This use case joins the CALLER's UnitOfWork transaction.
 *   - There is NO internal unitOfWork.run — opening a nested UoW here would
 *     defeat the atomicity contract required by the cascade.
 *   - The repo call commits atomically within the caller-supplied TxContext.
 *
 * Precedent: PseudonymiseEventsHostForUserUseCase (features/events) follows
 * the same two-arg A7-exception shape for the same reason.
 */
export class CascadeReviewsOnUserDeletionUseCase implements CascadeOnUserDeletionPort {
  constructor(private readonly reviews: ReviewRepository) {}

  async execute(input: { userId: string }, ctx: TxContext): Promise<void> {
    await this.reviews.deleteAllForUser(input.userId, ctx);
  }
}
