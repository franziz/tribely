import { createId } from '@paralleldrive/cuid2';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { FileStorage } from '@/core/storage/file-storage.port.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { RecordSelfieDeletionUseCase } from '@/features/audit/application/usecases/record-selfie-deletion.usecase.js';
import type { SelfieRepository } from '../../domain/repositories/selfie.repository.js';
import type { PendingStorageDeleteRepository } from '../../domain/repositories/pending-storage-delete.repository.js';
import type { SweepRunRepository } from '../../domain/repositories/sweep-run.repository.js';
import type { SweepRetainedSelfiesResult } from '../dto/sweep-retained-selfies.result.js';

/** 30 days expressed in milliseconds. */
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

/** Max attempts before an orphaned pending-delete row is left for manual ops resolution. */
const MAX_REAPER_ATTEMPTS = 10;

const SWEEP_KIND = 'selfie-retention-sweep' as const;

/**
 * PDPA-mandated selfie retention sweep.
 *
 * Finds selfies eligible for retention deletion (approved or rejected ≥ 30
 * days ago), processes each in its own DB transaction, and attempts
 * post-commit storage deletion with bounded retry.
 *
 * Per-record commit ordering (legally mandated):
 *   1. unitOfWork.run(async (ctx) => {
 *   2.   capture storageKey BEFORE markDeleted clears it
 *   3.   selfie.markDeleted(now, reason)
 *   4.   selfieRepository.save(selfie, ctx)
 *   5.   publisher.publish(ctx, ...selfie.pullEvents())
 *   6.   recordSelfieDeletionUseCase.execute({ ... }, ctx)   // audit row
 *   7.   if (storageKey) pendingStorageDeleteRepository.enqueue({ ... }, ctx)
 *   8. })  // DB COMMITS
 *   9. if (storageKey) attemptStorageDelete(selfieId, storageKey)  // post-commit
 *
 * Single-failure isolation: each record runs in its OWN unitOfWork.run.
 * A storage-delete failure on record #2 does NOT abort records #3..N.
 *
 * Idempotency: eligibility query filters on status IN ('approved','rejected').
 * After markDeleted flips status to 'deleted', the row never re-appears.
 *
 * Orphan reaper pass: after the eligibility pass, retries entries in
 * `selfie_pending_storage_deletes` from prior failed attempts. Bounded to
 * `attempts < MAX_REAPER_ATTEMPTS`; records reaching the cap remain for
 * manual ops resolution.
 *
 * `sweep_runs` row is written once per tick (after all per-record work) so
 * the regulator audit-trail answer for "did the sweep run on date X?" is
 * always present — even for zero-eligible ticks.
 */
export class SweepRetainedSelfiesUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly selfieRepository: SelfieRepository,
    private readonly pendingStorageDeleteRepository: PendingStorageDeleteRepository,
    private readonly sweepRunRepository: SweepRunRepository,
    private readonly recordSelfieDeletion: RecordSelfieDeletionUseCase,
    private readonly publisher: EventPublisher,
    private readonly fileStorage: FileStorage,
    private readonly clock: Clock,
    private readonly logger: Logger,
  ) {}

  async execute(): Promise<SweepRetainedSelfiesResult> {
    const startedAt = this.clock.now();
    const startMs = Date.now();
    const cutoff = new Date(startedAt.getTime() - THIRTY_DAYS_MS);

    let evaluated = 0;
    let deleted = 0;
    let failed = 0;
    let reaperRetried = 0;
    let reaperSucceeded = 0;

    try {
      // --- Eligibility pass ---
      const eligible = await this.selfieRepository.findEligibleForRetentionSweep(cutoff);
      evaluated = eligible.length;

      for (const selfie of eligible) {
        const reason = selfie.status === 'approved' ? 'retention-sweep' : 'reviewer-rejection-aged';

        // Capture storageKey BEFORE markDeleted clears it (step 2 in the commit ordering).
        const storageKey = selfie.storageKey;

        try {
          // Steps 3-8: single DB transaction per record.
          await this.unitOfWork.run(async (ctx) => {
            selfie.markDeleted(startedAt, reason);
            await this.selfieRepository.save(selfie, ctx);
            await this.publisher.publish(ctx, ...selfie.pullEvents());
            await this.recordSelfieDeletion.execute(
              {
                userId: selfie.userId,
                selfieId: selfie.id,
                reason,
                deletedAt: startedAt,
              },
              ctx,
            );
            if (storageKey !== null) {
              await this.pendingStorageDeleteRepository.enqueue(
                {
                  id: createId(),
                  selfieId: selfie.id,
                  storageKey,
                  attempts: 0,
                  enqueuedAt: startedAt,
                  lastAttemptAt: null,
                  lastError: null,
                },
                ctx,
              );
            }
          });
          // Step 9: post-commit storage delete (failure → log WARN, leave in pending table).
          if (storageKey !== null) {
            await this.attemptStorageDelete(selfie.id, storageKey);
          }
          deleted++;
        } catch (err) {
          failed++;
          this.logger.warn(
            { selfieId: selfie.id, userId: selfie.userId, err },
            'Selfie retention sweep: record failed',
          );
        }
      }

      // --- Orphan reaper pass ---
      const pending = await this.pendingStorageDeleteRepository.findPending();
      for (const entry of pending) {
        // Respect the cap: entries at or beyond MAX_REAPER_ATTEMPTS stay for manual resolution.
        if (entry.attempts >= MAX_REAPER_ATTEMPTS) {
          this.logger.warn(
            { selfieId: entry.selfieId, attempts: entry.attempts },
            'Selfie reaper: entry at max attempts, leaving for manual resolution',
          );
          continue;
        }

        reaperRetried++;
        try {
          await this.fileStorage.deleteObject({ key: entry.storageKey });
          // Success: remove from queue (no tx needed; queue mutation is idempotent).
          await this.pendingStorageDeleteRepository.remove(entry.selfieId);
          reaperSucceeded++;
        } catch (err) {
          await this.pendingStorageDeleteRepository.incrementAttempts(
            entry.selfieId,
            err instanceof Error ? err.message : String(err),
          );
          this.logger.warn(
            { selfieId: entry.selfieId, attempts: entry.attempts + 1, err },
            'Selfie reaper: storage delete failed, will retry next sweep',
          );
        }
      }
    } catch (err: unknown) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      // Write sweep_runs row with error before re-throwing.
      await this.writeSweepRun({
        startedAt,
        evaluated,
        deleted,
        failed,
        reaperRetried,
        reaperSucceeded,
        error: errorMsg,
      });
      throw err;
    }

    const durationMs = Date.now() - startMs;

    // Write sweep_runs row for the success path.
    await this.writeSweepRun({
      startedAt,
      evaluated,
      deleted,
      failed,
      reaperRetried,
      reaperSucceeded,
      error: null,
    });

    return { evaluated, deleted, failed, reaperRetried, reaperSucceeded, durationMs };
  }

  /**
   * Attempt to delete the S3 object post-commit. On failure, the entry was
   * already enqueued in `selfie_pending_storage_deletes` so it will be retried
   * by the next sweep's reaper pass.
   */
  private async attemptStorageDelete(selfieId: string, storageKey: string): Promise<void> {
    try {
      await this.fileStorage.deleteObject({ key: storageKey });
      // Success: remove the pending entry added during the DB tx.
      await this.pendingStorageDeleteRepository.remove(selfieId);
    } catch (err) {
      await this.pendingStorageDeleteRepository.incrementAttempts(
        selfieId,
        err instanceof Error ? err.message : String(err),
      );
      this.logger.warn(
        { selfieId, storageKey, err },
        'Selfie sweep: post-commit storage delete failed; entry left for reaper',
      );
    }
  }

  private async writeSweepRun(params: {
    startedAt: Date;
    evaluated: number;
    deleted: number;
    failed: number;
    reaperRetried: number;
    reaperSucceeded: number;
    error: string | null;
  }): Promise<void> {
    await this.sweepRunRepository
      .record({
        id: createId(),
        kind: SWEEP_KIND,
        startedAt: params.startedAt,
        finishedAt: this.clock.now(),
        evaluated: params.evaluated,
        deleted: params.deleted,
        failed: params.failed,
        reaperRetried: params.reaperRetried,
        reaperSucceeded: params.reaperSucceeded,
        error: params.error,
      })
      .catch((writeErr: unknown) => {
        this.logger.warn(
          { writeErr: writeErr instanceof Error ? writeErr.message : String(writeErr) },
          'Selfie sweep: failed to write sweep_runs row',
        );
      });
  }
}
