import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { PostEventCheckInReason } from '@/features/audit/domain/repositories/post-event-check-in-event.repository.js';

/**
 * Port describing the cross-feature audit recorder for post-event check-in
 * lifecycle events.
 *
 * Matches the structural shape of `RecordPostEventCheckInEventUseCase.execute`
 * in features/audit. Keeping a port here allows the check-ins application
 * layer to depend on an interface rather than a concrete class, which:
 *   - satisfies the A11 bounded-context rule (application ports are the
 *     sanctioned cross-feature import surface for use-case-shaped operations),
 *   - enables clean fakes in unit tests without importing the concrete class.
 *
 * The two-arg `execute(input, ctx)` signature signals the A7 exception:
 * callers MUST be inside their own `unitOfWork.run` and pass the TxContext
 * so the audit row commits atomically with the triggering mutation.
 */
export interface PostEventCheckInAuditPort {
  execute(
    input: {
      checkInId: string;
      userId: string;
      eventId: string;
      reason: PostEventCheckInReason;
      occurredAt: Date;
    },
    ctx: TxContext,
  ): Promise<void>;
}
