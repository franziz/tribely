import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { CascadeOnUserDeletionPort } from '../ports/cascade-on-user-deletion.port.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';

/**
 * Bulk-delete all reports associated with a user as part of a PDPA erasure
 * cascade. Removes:
 *   (a) reports filed BY the user (`reporterUserId = userId`), and
 *   (b) reports targeting reviews the user authored or was rated in
 *       (`targetType = 'review' AND targetId IN (deleter's review ids)`).
 *
 * Required-ctx two-arg execute(input, ctx) shape (A7 exception):
 *   - This use case joins the CALLER's UnitOfWork transaction.
 *   - There is NO internal unitOfWork.run — opening a nested UoW here would
 *     defeat the atomicity contract required by the cascade.
 *   - The repo call commits atomically within the caller-supplied TxContext.
 *
 * Polymorphic resolvers for targetType IN ('user', 'event') are deferred —
 * see TRI-30 spec and TRI-155 PM brief. The repo method body contains a
 * code comment referencing the deferral.
 */
export class CascadeReportsOnUserDeletionUseCase implements CascadeOnUserDeletionPort {
  constructor(private readonly reports: ReportRepository) {}

  async execute(input: { userId: string }, ctx: TxContext): Promise<void> {
    await this.reports.deleteAllForUser(input.userId, ctx);
  }
}
