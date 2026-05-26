import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  SweepRunEntry,
  SweepRunRepository,
} from '../../domain/repositories/sweep-run.repository.js';

export class SweepRunPrismaRepository implements SweepRunRepository {
  constructor(private readonly db: Db) {}

  async record(entry: SweepRunEntry, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    await client.sweepRun.create({
      data: {
        id: entry.id,
        kind: entry.kind,
        startedAt: entry.startedAt,
        finishedAt: entry.finishedAt,
        evaluated: entry.evaluated,
        deleted: entry.deleted,
        failed: entry.failed,
        reaperRetried: entry.reaperRetried,
        reaperSucceeded: entry.reaperSucceeded,
        error: entry.error,
        auditRowsSevered: entry.auditRowsSevered,
      },
    });
  }
}
