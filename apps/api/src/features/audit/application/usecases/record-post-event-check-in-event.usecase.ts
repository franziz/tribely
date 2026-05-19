import { createId } from '@paralleldrive/cuid2';
import { getRequestContext } from '@/core/context/request-context.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  PostEventCheckInEventEntry,
  PostEventCheckInEventRepository,
  PostEventCheckInReason,
} from '../../domain/repositories/post-event-check-in-event.repository.js';

export interface RecordPostEventCheckInEventInput {
  checkInId: string;
  userId: string;
  eventId: string;
  reason: PostEventCheckInReason;
  occurredAt: Date;
}

/**
 * Records one post-event check-in lifecycle event to the append-only audit
 * table.
 *
 * Atomicity contract: caller MUST be inside its own `unitOfWork.run` and
 * pass the supplied TxContext. The audit row commits atomically with the
 * triggering domain mutation (check-in create, acknowledge, flag, etc.).
 *
 * `requestId` is read from AsyncLocalStorage. HTTP callers see the live
 * request frame; the 24-month retention sweep wraps in `runAsSystem(...)`
 * producing a `system:<label>:<cuid>` synthetic requestId.
 *
 * This use case intentionally carries no local `unitOfWork.run` — it joins
 * the caller's transaction via the required `ctx` parameter. This is the
 * documented A7 exception (CLAUDE.md evidence-integrity pattern). The two-arg
 * `execute(input, ctx)` signature is the visible signal that this use case
 * must be invoked from inside an existing transaction.
 *
 * NO read methods on the public surface (auditor access is out-of-band SQL).
 * NO update/repair/backfill methods (legal integrity constraint).
 */
export class RecordPostEventCheckInEventUseCase {
  constructor(private readonly repository: PostEventCheckInEventRepository) {}

  async execute(input: RecordPostEventCheckInEventInput, ctx: TxContext): Promise<void> {
    const requestId = getRequestContext()?.requestId ?? null;
    const entry: PostEventCheckInEventEntry = {
      id: createId(),
      checkInId: input.checkInId,
      userId: input.userId,
      eventId: input.eventId,
      reason: input.reason,
      occurredAt: input.occurredAt,
      requestId,
      recordedAt: new Date(),
    };
    await this.repository.record(entry, ctx);
  }
}
