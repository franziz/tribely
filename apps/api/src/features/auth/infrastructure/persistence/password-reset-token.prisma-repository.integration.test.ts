// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';

import { PasswordResetToken } from '../../domain/entities/password-reset-token.js';
import { PasswordResetTokenPrismaRepository } from './password-reset-token.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * Integration tests for PasswordResetTokenPrismaRepository.deleteAllForUser
 * against the real Postgres DB. Skipped when DATABASE_URL is unset.
 *
 * Brief C acceptance: after deleteAllForUser, ALL password reset token rows
 * for user X are absent; rows for Y and Z are untouched.
 * The returned count matches the number of deleted rows.
 */
describe.skipIf(!dbUrl)('PasswordResetTokenPrismaRepository.deleteAllForUser (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let repo: PasswordResetTokenPrismaRepository;

  let userX: string;
  let userY: string;
  let userZ: string;

  const now = new Date('2026-05-19T00:00:00Z');
  const future = new Date('2027-01-01T00:00:00Z');

  const makeToken = (userId: string): PasswordResetToken =>
    PasswordResetToken.issue({
      id: createId(),
      userId,
      codeHash: `h:${createId()}`,
      expiresAt: future,
      now,
    });

  const saveToken = async (token: PasswordResetToken): Promise<void> => {
    await unitOfWork.run(async (ctx) => {
      await repo.save(token, ctx);
    });
  };

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    repo = new PasswordResetTokenPrismaRepository(db);

    userX = createId();
    userY = createId();
    userZ = createId();

    await db.user.createMany({
      data: [
        { id: userX, email: `prt-x-${userX}@tri134c.test`, displayName: 'TRI-134C PRT User X' },
        { id: userY, email: `prt-y-${userY}@tri134c.test`, displayName: 'TRI-134C PRT User Y' },
        { id: userZ, email: `prt-z-${userZ}@tri134c.test`, displayName: 'TRI-134C PRT User Z' },
      ],
    });

    // User X gets 2 tokens (one open, one consumed).
    const tokenX1 = makeToken(userX);
    const tokenX2 = makeToken(userX);
    tokenX2.consume(now);
    await saveToken(tokenX1);
    await saveToken(tokenX2);

    // Users Y and Z each get 1 open token.
    await saveToken(makeToken(userY));
    await saveToken(makeToken(userZ));
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.passwordResetToken
      .deleteMany({
        where: { userId: { in: [userX, userY, userZ] } },
      })
      .catch(() => null);
    await db.user.deleteMany({ where: { id: { in: [userX, userY, userZ] } } }).catch(() => null);
    await db.$disconnect();
  });

  it('removes all password reset token rows for user X and returns count 2', async () => {
    let count = 0;
    await unitOfWork.run(async (ctx) => {
      count = await repo.deleteAllForUser(userX, ctx);
    });

    expect(count).toBe(2);

    const remaining = await db.passwordResetToken.findMany({ where: { userId: userX } });
    expect(remaining).toHaveLength(0);
  });

  it('leaves password reset tokens for users Y and Z untouched', async () => {
    const rowsY = await db.passwordResetToken.findMany({ where: { userId: userY } });
    const rowsZ = await db.passwordResetToken.findMany({ where: { userId: userZ } });

    expect(rowsY).toHaveLength(1);
    expect(rowsZ).toHaveLength(1);
  });

  it('returns 0 when the user has no tokens', async () => {
    const emptyUserId = createId();
    await db.user.create({
      data: {
        id: emptyUserId,
        email: `prt-empty-${emptyUserId}@tri134c.test`,
        displayName: 'Empty PRT User',
      },
    });

    try {
      let count = 0;
      await unitOfWork.run(async (ctx) => {
        count = await repo.deleteAllForUser(emptyUserId, ctx);
      });
      expect(count).toBe(0);
    } finally {
      await db.user.delete({ where: { id: emptyUserId } }).catch(() => null);
    }
  });
});
