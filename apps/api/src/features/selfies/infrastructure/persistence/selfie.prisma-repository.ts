import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Selfie } from '../../domain/entities/selfie.js';
import type { SelfieRepository } from '../../domain/repositories/selfie.repository.js';
import { toSelfie, toRow } from './selfie.mapper.js';

export class SelfiePrismaRepository implements SelfieRepository {
  constructor(private readonly db: Db) {}

  async save(selfie: Selfie, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    await client.selfie.upsert({
      where: { id: selfie.id },
      create: toRow(selfie),
      update: {
        status: selfie.status,
        storageKey: selfie.storageKey,
        approvedAt: selfie.approvedAt,
        rejectedAt: selfie.rejectedAt,
        deletedAt: selfie.deletedAt,
        updatedAt: selfie.updatedAt,
      },
    });
  }

  async findActiveByUserId(userId: string, ctx?: TxContext): Promise<Selfie | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    // "Active" means status ∈ {pending, approved, rejected} — excludes deleted.
    // Returns the most recently created non-deleted selfie for the user.
    const row = await client.selfie.findFirst({
      where: {
        userId,
        status: { in: ['pending', 'approved', 'rejected'] },
      },
      orderBy: { createdAt: 'desc' },
    });
    return row ? toSelfie(row) : null;
  }

  async findEligibleForRetentionSweep(cutoff: Date, ctx?: TxContext): Promise<Selfie[]> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    // Eligible rows:
    //   - status = 'approved' AND approvedAt < cutoff, OR
    //   - status = 'rejected' AND rejectedAt < cutoff
    // Excludes `pending` (no terminal timestamp yet) and `deleted` (already processed).
    const rows = await client.selfie.findMany({
      where: {
        OR: [
          { status: 'approved', approvedAt: { lt: cutoff } },
          { status: 'rejected', rejectedAt: { lt: cutoff } },
        ],
      },
      orderBy: { createdAt: 'asc' },
    });
    return rows.map(toSelfie);
  }
}
