import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  SelfieDeletionEventRecord,
  SelfieDeletionEventRepository,
} from '../../domain/repositories/selfie-deletion-event.repository.js';

export class SelfieDeletionEventPrismaRepository implements SelfieDeletionEventRepository {
  constructor(private readonly db: Db) {}

  async record(entry: SelfieDeletionEventRecord, ctx: TxContext): Promise<void> {
    const client = unwrapTx(ctx);
    await client.selfieDeletionEvent.create({
      data: {
        id: entry.id,
        userId: entry.userId,
        selfieId: entry.selfieId,
        reason: entry.reason,
        deletedAt: entry.deletedAt,
        requestId: entry.requestId,
        recordedAt: entry.recordedAt,
      },
    });
  }

  async pruneOlderThan(cutoff: Date, ctx: TxContext): Promise<number> {
    const client = unwrapTx(ctx);
    const result = await client.selfieDeletionEvent.deleteMany({
      where: { deletedAt: { lt: cutoff } },
    });
    return result.count;
  }
}
