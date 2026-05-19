import { createId } from '@paralleldrive/cuid2';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { RecordSelfieDeletionUseCase } from '@/features/audit/application/usecases/record-selfie-deletion.usecase.js';
import type { SelfieDeletionReason } from '@/features/audit/domain/repositories/selfie-deletion-event.repository.js';
import type { SelfieRepository } from '../../domain/repositories/selfie.repository.js';
import type { PendingStorageDeleteRepository } from '../../domain/repositories/pending-storage-delete.repository.js';

export interface DeleteSelfieForUserInput {
  userId: string;
  reason: SelfieDeletionReason;
}

/**
 * Cascade hook for account-deletion and other user-scoped deletion flows.
 *
 * Evidence-integrity pattern: the caller MUST supply a `ctx` from its own
 * `unitOfWork.run`. The selfie mutation, audit row, and pending-storage-delete
 * enqueue all commit atomically with the surrounding transaction.
 *
 * Two-arg `execute(input, ctx)` signature is the deliberate signal that this
 * use case must be called from inside an existing transaction (mirrors
 * `RecordSelfieDeletionUseCase` — see CLAUDE.md §evidence-integrity).
 *
 * Storage delete is NOT performed inline; it is deferred to the next sweep's
 * orphan-reaper pass via `PendingStorageDeleteRepository.enqueue`.
 *
 * Idempotent on no-active-selfie: if `findActiveByUserId` returns null, the
 * use case returns without writing any rows.
 */
export class DeleteSelfieForUserUseCase {
  constructor(
    private readonly selfieRepository: SelfieRepository,
    private readonly pendingStorageDeleteRepository: PendingStorageDeleteRepository,
    private readonly recordSelfieDeletion: RecordSelfieDeletionUseCase,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: DeleteSelfieForUserInput, ctx: TxContext): Promise<void> {
    const selfie = await this.selfieRepository.findActiveByUserId(input.userId, ctx);

    // Idempotent on no-op: user never uploaded or already deleted.
    if (selfie === null) {
      return;
    }

    const now = this.clock.now();

    // Capture storageKey BEFORE markDeleted clears it.
    const storageKey = selfie.storageKey;

    selfie.markDeleted(now, input.reason);

    await this.selfieRepository.save(selfie, ctx);
    await this.publisher.publish(ctx, ...selfie.pullEvents());
    await this.recordSelfieDeletion.execute(
      { userId: input.userId, selfieId: selfie.id, reason: input.reason, deletedAt: now },
      ctx,
    );

    // Enqueue inside the caller's ctx so the storage delete entry commits
    // atomically with the selfie mutation. The actual S3 call is deferred to
    // the reaper pass in SweepRetainedSelfiesUseCase.
    if (storageKey !== null) {
      await this.pendingStorageDeleteRepository.enqueue(
        {
          id: createId(),
          selfieId: selfie.id,
          storageKey,
          attempts: 0,
          enqueuedAt: now,
          lastAttemptAt: null,
          lastError: null,
        },
        ctx,
      );
    }
  }
}
