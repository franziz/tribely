import { createId } from '@paralleldrive/cuid2';
import { getRequestContext } from '@/core/context/request-context.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  SelfieDeletionEventRecord,
  SelfieDeletionEventRepository,
  SelfieDeletionReason,
} from '../../domain/repositories/selfie-deletion-event.repository.js';

export interface RecordSelfieDeletionInput {
  userId: string;
  selfieId: string;
  reason: SelfieDeletionReason;
  deletedAt: Date;
}

/**
 * Records one selfie-deletion event to the append-only audit table.
 *
 * Atomicity contract: caller MUST be inside its own `unitOfWork.run` and
 * pass the supplied TxContext. The audit row commits atomically with the
 * triggering domain mutation (selfie row delete, account cascade, etc.).
 *
 * `requestId` is read from AsyncLocalStorage. HTTP callers see the live
 * request frame; the 24-month retention sweep wraps in `runAsSystem(...)`
 * producing a `system:<label>:<cuid>` synthetic requestId.
 *
 * The cascade (account-deletion → selfie-deletion → audit) uses the
 * SYNC path (TRI-82 EL ruling on Q2): inline call inside the deletion
 * use case's own UoW. NOT an event-consumer pattern — evidence-integrity
 * domain, all-or-nothing matters more than fan-out flexibility.
 *
 * NO read methods on the public surface (auditor access is out-of-band
 * SQL). NO update/repair/backfill methods (legal Q3 constraint).
 */
export class RecordSelfieDeletionUseCase {
  constructor(private readonly repository: SelfieDeletionEventRepository) {}

  async execute(input: RecordSelfieDeletionInput, ctx: TxContext): Promise<void> {
    const requestId = getRequestContext()?.requestId ?? null;
    const record: SelfieDeletionEventRecord = {
      id: createId(),
      userId: input.userId,
      selfieId: input.selfieId,
      reason: input.reason,
      deletedAt: input.deletedAt,
      requestId,
      recordedAt: new Date(),
    };
    await this.repository.record(record, ctx);
  }
}
