// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';

import { RefreshToken } from '../../domain/entities/refresh-token.js';
import { RefreshTokenPrismaRepository } from './refresh-token.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * Integration tests for RefreshTokenPrismaRepository.deleteAllForUser against
 * the real Postgres DB. Skipped when DATABASE_URL is unset.
 *
 * Brief C acceptance: after deleteAllForUser, ALL refresh token rows for user X
 * (active and revoked) are absent; rows for Y and Z are untouched.
 * The returned count matches the number of deleted rows.
 */
describe.skipIf(!dbUrl)('RefreshTokenPrismaRepository.deleteAllForUser (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let repo: RefreshTokenPrismaRepository;

  let userX: string;
  let userY: string;
  let userZ: string;

  const now = new Date('2026-05-19T00:00:00Z');
  const future = new Date('2027-01-01T00:00:00Z');

  const makeToken = (userId: string): RefreshToken =>
    RefreshToken.issue({
      id: createId(),
      userId,
      tokenHash: `hash-${createId()}`,
      expiresAt: future,
      deviceLabel: null,
      now,
    });

  const saveToken = async (token: RefreshToken): Promise<void> => {
    await unitOfWork.run(async (ctx) => {
      await repo.save(token, ctx);
    });
  };

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    repo = new RefreshTokenPrismaRepository(db);

    userX = createId();
    userY = createId();
    userZ = createId();

    await db.user.createMany({
      data: [
        { id: userX, email: `rt-x-${userX}@tri134c.test`, displayName: 'TRI-134C RT User X' },
        { id: userY, email: `rt-y-${userY}@tri134c.test`, displayName: 'TRI-134C RT User Y' },
        { id: userZ, email: `rt-z-${userZ}@tri134c.test`, displayName: 'TRI-134C RT User Z' },
      ],
    });

    // User X gets 2 tokens (one active, one revoked).
    const tokenX1 = makeToken(userX);
    const tokenX2 = makeToken(userX);
    tokenX2.revoke('signed_out', now);
    await saveToken(tokenX1);
    await saveToken(tokenX2);

    // Users Y and Z each get 1 active token.
    await saveToken(makeToken(userY));
    await saveToken(makeToken(userZ));
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.refreshToken.deleteMany({
      where: { userId: { in: [userX, userY, userZ] } },
    }).catch(() => null);
    await db.user.deleteMany({ where: { id: { in: [userX, userY, userZ] } } }).catch(() => null);
    await db.$disconnect();
  });

  it('removes all refresh token rows for user X and returns count 2', async () => {
    let count = 0;
    await unitOfWork.run(async (ctx) => {
      count = await repo.deleteAllForUser(userX, ctx);
    });

    expect(count).toBe(2);

    const remaining = await db.refreshToken.findMany({ where: { userId: userX } });
    expect(remaining).toHaveLength(0);
  });

  it('leaves refresh tokens for users Y and Z untouched', async () => {
    const rowsY = await db.refreshToken.findMany({ where: { userId: userY } });
    const rowsZ = await db.refreshToken.findMany({ where: { userId: userZ } });

    expect(rowsY).toHaveLength(1);
    expect(rowsZ).toHaveLength(1);
  });

  it('returns 0 when the user has no tokens', async () => {
    const emptyUserId = createId();
    await db.user.create({
      data: {
        id: emptyUserId,
        email: `rt-empty-${emptyUserId}@tri134c.test`,
        displayName: 'Empty RT User',
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
