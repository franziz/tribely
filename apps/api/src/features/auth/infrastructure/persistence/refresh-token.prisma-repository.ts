import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { RefreshToken } from '../../domain/entities/refresh-token.js';
import type { RefreshTokenRevokedReason } from '../../domain/events/refresh-token-revoked.event.js';
import type { RefreshTokenRepository } from '../../domain/repositories/refresh-token.repository.js';
import { toRefreshToken, toRow } from './refresh-token.mapper.js';

export class RefreshTokenPrismaRepository implements RefreshTokenRepository {
  constructor(private readonly db: Db) {}

  async findByTokenHash(hash: string, ctx?: TxContext): Promise<RefreshToken | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.refreshToken.findUnique({ where: { tokenHash: hash } });
    return row ? toRefreshToken(row) : null;
  }

  async findById(id: string, ctx?: TxContext): Promise<RefreshToken | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.refreshToken.findUnique({ where: { id } });
    return row ? toRefreshToken(row) : null;
  }

  async save(token: RefreshToken, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = toRow(token);
    await client.refreshToken.upsert({
      where: { id: row.id },
      create: row,
      update: {
        revokedAt: row.revokedAt,
        revokedReason: row.revokedReason,
        lastUsedAt: row.lastUsedAt,
        rotatedToId: row.rotatedToId,
      },
    });
  }

  async revokeAllActiveForUser(
    userId: string,
    reason: RefreshTokenRevokedReason,
    now: Date,
    ctx?: TxContext,
  ): Promise<RefreshToken[]> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const active = await client.refreshToken.findMany({
      where: { userId, revokedAt: null },
    });
    if (active.length === 0) return [];
    await client.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: now, revokedReason: reason },
    });
    // Return the now-revoked aggregates so the caller can publish events.
    return active.map((row) => {
      const token = toRefreshToken(row);
      token.revoke(reason, now);
      return token;
    });
  }

  async deleteAllForUser(userId: string, ctx: TxContext): Promise<number> {
    const client = unwrapTx(ctx);
    const result = await client.refreshToken.deleteMany({ where: { userId } });
    return result.count;
  }
}
