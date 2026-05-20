import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { PasswordResetToken } from '../../domain/entities/password-reset-token.js';
import type { PasswordResetTokenRepository } from '../../domain/repositories/password-reset-token.repository.js';
import { toPasswordResetToken, toRow } from './password-reset-token.mapper.js';

export class PasswordResetTokenPrismaRepository implements PasswordResetTokenRepository {
  constructor(private readonly db: Db) {}

  async findById(id: string, ctx?: TxContext): Promise<PasswordResetToken | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.passwordResetToken.findUnique({ where: { id } });
    return row ? toPasswordResetToken(row) : null;
  }

  async findOpenByUserId(userId: string, ctx?: TxContext): Promise<PasswordResetToken | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.passwordResetToken.findFirst({
      where: {
        userId,
        consumedAt: null,
        invalidated: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { issuedAt: 'desc' },
    });
    return row ? toPasswordResetToken(row) : null;
  }

  async save(token: PasswordResetToken, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = toRow(token);
    await client.passwordResetToken.upsert({
      where: { id: row.id },
      create: row,
      update: {
        consumedAt: row.consumedAt,
        attempts: row.attempts,
        invalidated: row.invalidated,
      },
    });
  }

  async deleteAllForUser(userId: string, ctx: TxContext): Promise<number> {
    const client = unwrapTx(ctx);
    const result = await client.passwordResetToken.deleteMany({ where: { userId } });
    return result.count;
  }
}
