import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * A queued request to delete a selfie's backing storage object (e.g. S3).
 *
 * Enqueued atomically alongside the selfie's `markDeleted` mutation so that
 * even if the storage-deletion worker crashes, the job survives and retries.
 * `attempts` + `lastError` support bounded retry with error surfacing.
 */
export interface PendingStorageDeleteEntry {
  id: string;
  selfieId: string;
  storageKey: string;
  attempts: number;
  enqueuedAt: Date;
  lastAttemptAt: Date | null;
  lastError: string | null;
}

export interface PendingStorageDeleteRepository {
  /**
   * Enqueue a storage-delete job. Must be called inside the same UnitOfWork
   * transaction as `SelfieRepository.save` so the queue entry and the selfie
   * mutation commit atomically.
   */
  enqueue(entry: PendingStorageDeleteEntry, ctx?: TxContext): Promise<void>;

  /**
   * Returns all pending entries ordered by `enqueuedAt ASC` (oldest first).
   * "Pending" means not yet removed — includes entries with failed attempts.
   */
  findPending(): Promise<PendingStorageDeleteEntry[]>;

  /**
   * Increment the attempt counter and record the error string (if any).
   * Sets `lastAttemptAt` to now. Used by the storage-delete worker after a
   * failed attempt.
   */
  incrementAttempts(selfieId: string, error?: string, ctx?: TxContext): Promise<void>;

  /**
   * Remove the entry after a successful storage deletion.
   * Must be called inside a UnitOfWork transaction if the caller needs
   * atomicity with another mutation.
   */
  remove(selfieId: string, ctx?: TxContext): Promise<void>;
}
