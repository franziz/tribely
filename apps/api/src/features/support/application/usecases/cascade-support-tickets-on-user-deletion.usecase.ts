import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { CascadeOnUserDeletionPort } from '../ports/cascade-on-user-deletion.port.js';
import type { SupportTicketRepository } from '../../domain/repositories/support-ticket.repository.js';

/**
 * Pseudonymise all support tickets submitted by a user as part of a PDPA
 * erasure cascade on account deletion (TRI-217).
 *
 * Required-ctx two-arg execute(input, ctx) shape (A7 exception):
 *   - This use case joins the CALLER's UnitOfWork transaction.
 *   - There is NO internal unitOfWork.run — opening a nested UoW here would
 *     defeat the atomicity contract required by the cascade.
 *   - The repo call commits atomically within the caller-supplied TxContext.
 *
 * Precedent: CascadeReviewsOnUserDeletionUseCase (features/reviews) follows
 * the same two-arg A7-exception shape for the same reason.
 */
export class CascadeSupportTicketsOnUserDeletionUseCase implements CascadeOnUserDeletionPort {
  constructor(private readonly supportTickets: SupportTicketRepository) {}

  async execute(input: { userId: string }, ctx: TxContext): Promise<void> {
    await this.supportTickets.pseudonymiseForUser(input.userId, ctx);
  }
}
