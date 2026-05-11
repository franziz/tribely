import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { User } from '../../domain/entities/user.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import type { Email } from '../../domain/value-objects/email.js';
import { toRow, toUser } from './user.mapper.js';

export class UserPrismaRepository implements UserRepository {
  constructor(private readonly db: Db) {}

  async findById(id: string, ctx?: TxContext): Promise<User | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.user.findUnique({ where: { id } });
    return row ? toUser(row) : null;
  }

  async findByEmail(email: Email, ctx?: TxContext): Promise<User | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.user.findUnique({ where: { email: email.value } });
    return row ? toUser(row) : null;
  }

  async save(user: User, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = toRow(user);
    await client.user.upsert({
      where: { id: row.id },
      create: row,
      update: {
        email: row.email,
        displayName: row.displayName,
        updatedAt: row.updatedAt,
        emailVerifiedAt: row.emailVerifiedAt,
        bio: row.bio,
        avatarUrl: row.avatarUrl,
        languages: row.languages,
        interests: row.interests,
        currentCity: row.currentCity,
        travelerType: row.travelerType,
      },
    });
  }
}
