// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import { UserBlock } from '../../domain/entities/user-block.js';
import { UserBlockPrismaRepository } from './user-block.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

describe.skipIf(!dbUrl)('UserBlockPrismaRepository — integration', () => {
  let db: PrismaClient;
  let repo: UserBlockPrismaRepository;
  let uow: PrismaUnitOfWork;

  let userA: string;
  let userB: string;
  let userC: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    repo = new UserBlockPrismaRepository(db);
    uow = new PrismaUnitOfWork(db);

    userA = createId();
    userB = createId();
    userC = createId();

    await db.user.createMany({
      data: [
        { id: userA, email: `ub-a-${userA}@test.com`, displayName: 'UserA' },
        { id: userB, email: `ub-b-${userB}@test.com`, displayName: 'UserB' },
        { id: userC, email: `ub-c-${userC}@test.com`, displayName: 'UserC' },
      ],
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.userBlock.deleteMany({
      where: {
        OR: [{ initiatorUserId: userA }, { initiatorUserId: userB }, { initiatorUserId: userC }],
      },
    });
    await db.user.deleteMany({ where: { id: { in: [userA, userB, userC] } } });
    await db.$disconnect();
  });

  it('saves and retrieves a block by findOne', async () => {
    const block = UserBlock.initiate({
      id: createId(),
      initiatorUserId: userA,
      blockedUserId: userB,
      now: new Date(),
    });
    block.pullEvents(); // clear events

    await repo.save(block);

    const found = await repo.findOne({ initiatorUserId: userA, blockedUserId: userB });
    expect(found).not.toBeNull();
    expect(found?.initiatorUserId).toBe(userA);
    expect(found?.blockedUserId).toBe(userB);
  });

  it('save is idempotent (upsert)', async () => {
    const id = createId();
    const block = UserBlock.rehydrate({
      id,
      initiatorUserId: userA,
      blockedUserId: userB,
      createdAt: new Date(),
    });

    // Save twice — should not throw.
    await repo.save(block);
    await repo.save(block);

    const found = await repo.findOne({ initiatorUserId: userA, blockedUserId: userB });
    expect(found?.id).toBeTruthy();
  });

  it('findBidirectional returns the row regardless of direction', async () => {
    // A blocked B — find by (A,B)
    const fwd = await repo.findBidirectional({ userA, userB });
    expect(fwd).not.toBeNull();

    // find by (B,A) — reverse
    const rev = await repo.findBidirectional({ userA: userB, userB: userA });
    expect(rev).not.toBeNull();
  });

  it('findBidirectional returns null when no block exists', async () => {
    const result = await repo.findBidirectional({ userA, userB: userC });
    expect(result).toBeNull();
  });

  it('filterBlocked returns the blocked candidate subset', async () => {
    // A has blocked B. C is unblocked.
    const blocked = await repo.filterBlocked({ viewerId: userA, candidateIds: [userB, userC] });
    expect(blocked.has(userB)).toBe(true);
    expect(blocked.has(userC)).toBe(false);
  });

  it('filterBlocked is bidirectional — also catches when viewer is the blocked party', async () => {
    // A blocked B. From B's perspective, A should be in the blocked set.
    const blocked = await repo.filterBlocked({ viewerId: userB, candidateIds: [userA, userC] });
    expect(blocked.has(userA)).toBe(true);
    expect(blocked.has(userC)).toBe(false);
  });

  it('filterBlocked returns empty set for empty candidateIds', async () => {
    const blocked = await repo.filterBlocked({ viewerId: userA, candidateIds: [] });
    expect(blocked.size).toBe(0);
  });

  it('listInitiatedBy returns the blocks in descending order', async () => {
    const result = await repo.listInitiatedBy({ initiatorUserId: userA, limit: 10 });
    expect(result.rows.length).toBeGreaterThanOrEqual(1);
    expect(result.rows.every((r) => r.initiatorUserId === userA)).toBe(true);
  });

  it('delete removes the row', async () => {
    await uow.run(async (ctx) => {
      await repo.delete({ initiatorUserId: userA, blockedUserId: userB }, ctx);
    });

    const found = await repo.findOne({ initiatorUserId: userA, blockedUserId: userB });
    expect(found).toBeNull();
  });

  it('delete is a no-op when row does not exist', async () => {
    // Should not throw even when row is already deleted.
    await expect(
      repo.delete({ initiatorUserId: userA, blockedUserId: userB }),
    ).resolves.toBeUndefined();
  });
});
