import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Credential } from '../../domain/entities/credential.js';
import type { CredentialRepository } from '../../domain/repositories/credential.repository.js';
import { toCredential, toRow } from './credential.mapper.js';

export class CredentialPrismaRepository implements CredentialRepository {
  constructor(private readonly db: Db) {}

  async findByUserId(userId: string, ctx?: TxContext): Promise<Credential | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.credential.findUnique({ where: { userId } });
    return row ? toCredential(row) : null;
  }

  async save(credential: Credential, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = toRow(credential);
    await client.credential.upsert({
      where: { userId: row.userId },
      create: row,
      update: {
        passwordHash: row.passwordHash,
        passwordSetAt: row.passwordSetAt,
        lastSignedInAt: row.lastSignedInAt,
      },
    });
  }
}
