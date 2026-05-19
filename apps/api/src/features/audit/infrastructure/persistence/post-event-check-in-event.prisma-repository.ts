import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  PostEventCheckInEventEntry,
  PostEventCheckInEventRepository,
} from '../../domain/repositories/post-event-check-in-event.repository.js';

export class PostEventCheckInEventPrismaRepository implements PostEventCheckInEventRepository {
  constructor(private readonly db: Db) {}

  async record(entry: PostEventCheckInEventEntry, ctx: TxContext): Promise<void> {
    const client = unwrapTx(ctx);
    await client.postEventCheckInEvent.create({
      data: {
        id: entry.id,
        checkInId: entry.checkInId,
        userId: entry.userId,
        eventId: entry.eventId,
        reason: entry.reason,
        occurredAt: entry.occurredAt,
        requestId: entry.requestId,
        recordedAt: entry.recordedAt,
      },
    });
  }

  async pruneOlderThan(cutoff: Date, ctx: TxContext): Promise<number> {
    const client = unwrapTx(ctx);
    const result = await client.postEventCheckInEvent.deleteMany({
      where: { occurredAt: { lt: cutoff } },
    });
    return result.count;
  }
}
