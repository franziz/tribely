import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { EmailVerificationToken } from '../../domain/entities/email-verification-token.js';
import type { EmailVerificationTokenRepository } from '../../domain/repositories/email-verification-token.repository.js';
import { toEmailVerificationToken, toRow } from './email-verification-token.mapper.js';

export class EmailVerificationTokenPrismaRepository implements EmailVerificationTokenRepository {
  constructor(private readonly db: Db) {}

  async findById(id: string, ctx?: TxContext): Promise<EmailVerificationToken | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.emailVerificationToken.findUnique({ where: { id } });
    return row ? toEmailVerificationToken(row) : null;
  }

  async findOpenByUserId(userId: string, ctx?: TxContext): Promise<EmailVerificationToken | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.emailVerificationToken.findFirst({
      where: {
        userId,
        consumedAt: null,
        invalidated: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { issuedAt: 'desc' },
    });
    return row ? toEmailVerificationToken(row) : null;
  }

  async save(token: EmailVerificationToken, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = toRow(token);
    await client.emailVerificationToken.upsert({
      where: { id: row.id },
      create: row,
      update: {
        consumedAt: row.consumedAt,
        attempts: row.attempts,
        invalidated: row.invalidated,
      },
    });
  }
}
