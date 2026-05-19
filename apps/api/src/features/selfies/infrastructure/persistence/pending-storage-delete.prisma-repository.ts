import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  PendingStorageDeleteEntry,
  PendingStorageDeleteRepository,
} from '../../domain/repositories/pending-storage-delete.repository.js';

/**
 * Map a Prisma SelfiePendingStorageDelete row to the domain entry shape.
 * Intentionally not exported — internal to this adapter.
 */
const toEntry = (row: {
  id: string;
  selfieId: string;
  storageKey: string;
  attempts: number;
  enqueuedAt: Date;
  lastAttemptAt: Date | null;
  lastError: string | null;
}): PendingStorageDeleteEntry => ({
  id: row.id,
  selfieId: row.selfieId,
  storageKey: row.storageKey,
  attempts: row.attempts,
  enqueuedAt: row.enqueuedAt,
  lastAttemptAt: row.lastAttemptAt,
  lastError: row.lastError,
});

export class PendingStorageDeletePrismaRepository implements PendingStorageDeleteRepository {
  constructor(private readonly db: Db) {}

  async enqueue(entry: PendingStorageDeleteEntry, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    await client.selfiePendingStorageDelete.create({
      data: {
        id: entry.id,
        selfieId: entry.selfieId,
        storageKey: entry.storageKey,
        attempts: entry.attempts,
        enqueuedAt: entry.enqueuedAt,
        lastAttemptAt: entry.lastAttemptAt,
        lastError: entry.lastError,
      },
    });
  }

  async findPending(): Promise<PendingStorageDeleteEntry[]> {
    const rows = await this.db.selfiePendingStorageDelete.findMany({
      orderBy: { enqueuedAt: 'asc' },
    });
    return rows.map(toEntry);
  }

  async incrementAttempts(selfieId: string, error?: string, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    await client.selfiePendingStorageDelete.updateMany({
      where: { selfieId },
      data: {
        attempts: { increment: 1 },
        lastAttemptAt: new Date(),
        lastError: error ?? null,
      },
    });
  }

  async remove(selfieId: string, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    await client.selfiePendingStorageDelete.deleteMany({
      where: { selfieId },
    });
  }
}
