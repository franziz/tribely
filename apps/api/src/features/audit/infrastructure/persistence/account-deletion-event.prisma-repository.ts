import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  AccountDeletionEventRecord,
  AccountDeletionEventRepository,
} from '../../domain/repositories/account-deletion-event.repository.js';

export class AccountDeletionEventPrismaRepository implements AccountDeletionEventRepository {
  constructor(private readonly db: Db) {}

  async record(entry: AccountDeletionEventRecord, ctx: TxContext): Promise<void> {
    const client = unwrapTx(ctx);
    await client.accountDeletionEvent.create({
      data: {
        id: entry.id,
        userIdHash: entry.userIdHash,
        requestedAt: entry.requestedAt,
        completedAt: entry.completedAt,
        requestId: entry.requestId,
        cascadeScope: entry.cascadeScope,
        outcome: entry.outcome,
        failureReason: entry.failureReason,
        recordedAt: entry.recordedAt,
      },
    });
  }
}
