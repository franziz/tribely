import { createId } from '@paralleldrive/cuid2';
import { getRequestContext } from '@/core/context/request-context.js';
import { sha256Hex } from '@/core/crypto/sha256-hex.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  AccountDeletionCascadeScope,
  AccountDeletionEventRecord,
  AccountDeletionEventRepository,
  AccountDeletionOutcome,
} from '../../domain/repositories/account-deletion-event.repository.js';

export interface RecordAccountDeletionInput {
  /** Raw userId — will be SHA-256 hashed before writing; plaintext is never persisted. */
  userId: string;
  requestedAt: Date;
  completedAt: Date;
  cascadeScope: AccountDeletionCascadeScope[];
  outcome: AccountDeletionOutcome;
  failureReason?: string | null;
}

/**
 * Records one account-deletion event to the append-only audit table.
 *
 * Atomicity contract: caller MUST be inside its own `unitOfWork.run` and
 * pass the supplied TxContext. The audit row commits atomically with the
 * triggering account-deletion cascade mutation.
 *
 * "Account deleted but audit row absent" is a legal incident under PDPA s24
 * evidence integrity — hence the non-optional `ctx` parameter (compile-time
 * enforcement of the atomicity contract, not a runtime check).
 *
 * `requestId` is read from AsyncLocalStorage. HTTP callers see the live
 * request frame; non-HTTP callers (cron, CLI) must wrap in `runAsSystem(...)`
 * which produces a `system:<label>:<cuid>` synthetic requestId.
 *
 * A7 exception: this use case intentionally has no local `unitOfWork.run`
 * because it joins the caller's transaction via the required-ctx pattern.
 * The caller's UoW frame IS the enclosing UoW. Accepted-with-rationale per
 * CLAUDE.md "Evidence-integrity required-ctx audit pattern" / A7 exception.
 *
 * NO read methods on the public surface (auditor access is out-of-band SQL).
 * NO update/repair/backfill methods (PDPA s24 legal constraint).
 */
export class RecordAccountDeletionUseCase {
  constructor(private readonly repository: AccountDeletionEventRepository) {}

  async execute(input: RecordAccountDeletionInput, ctx: TxContext): Promise<void> {
    const requestId = getRequestContext()?.requestId ?? null;
    const record: AccountDeletionEventRecord = {
      id: createId(),
      userIdHash: sha256Hex(input.userId),
      requestedAt: input.requestedAt,
      completedAt: input.completedAt,
      requestId,
      cascadeScope: input.cascadeScope,
      outcome: input.outcome,
      failureReason: input.failureReason ?? null,
      recordedAt: new Date(),
    };
    await this.repository.record(record, ctx);
  }
}
