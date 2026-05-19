// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { JwtAccessTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-access-token-issuer.js';
import { buildApp } from '../../../../../app.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * HTTP-level integration tests for user-blocks routes.
 * Exercises the full stack: JWT auth middleware → route → controller →
 * use case → Prisma repository → DB.
 * Skipped when DATABASE_URL is unset.
 */
describe.skipIf(!dbUrl)('user-blocks HTTP routes (integration)', () => {
  let db: PrismaClient;
  let initiatorToken: string;
  let initiatorUserId: string;
  let targetUserId: string;
  let otherUserId: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    initiatorUserId = createId();
    targetUserId = createId();
    otherUserId = createId();

    await db.user.createMany({
      data: [
        {
          id: initiatorUserId,
          email: `ub-init-${initiatorUserId}@route.test`,
          displayName: 'Initiator',
          emailVerifiedAt: new Date(),
        },
        {
          id: targetUserId,
          email: `ub-target-${targetUserId}@route.test`,
          displayName: 'Target',
        },
        {
          id: otherUserId,
          email: `ub-other-${otherUserId}@route.test`,
          displayName: 'Other',
        },
      ],
    });

    const issued = await tokens.issue({
      userId: initiatorUserId,
      email: `ub-init-${initiatorUserId}@route.test`,
    });
    initiatorToken = issued.value;
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.userBlock.deleteMany({
      where: {
        OR: [
          { initiatorUserId },
          { initiatorUserId: targetUserId },
          { blockedUserId: initiatorUserId },
        ],
      },
    });
    await db.user.deleteMany({
      where: { id: { in: [initiatorUserId, targetUserId, otherUserId] } },
    });
    await db.$disconnect();
  });

  describe('POST /me/blocks', () => {
    it('200 — blocks a user and returns the block', async () => {
      const { app } = buildApp();
      const res = await app.request('/me/blocks', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${initiatorToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ blockedUserId: targetUserId }),
      });

      expect(res.status).toBe(200);
      const body = (await res.json()) as { block: { id: string; blockedUserId: string } };
      expect(body.block.blockedUserId).toBe(targetUserId);
    });

    it('200 — idempotent: blocking already-blocked user returns existing block', async () => {
      const { app } = buildApp();
      const res = await app.request('/me/blocks', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${initiatorToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ blockedUserId: targetUserId }),
      });

      expect(res.status).toBe(200);
      // Verify only one block row exists in DB.
      const count = await db.userBlock.count({
        where: { initiatorUserId, blockedUserId: targetUserId },
      });
      expect(count).toBe(1);
    });

    it('400 — rejects invalid body (missing blockedUserId)', async () => {
      const { app } = buildApp();
      const res = await app.request('/me/blocks', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${initiatorToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({}),
      });

      expect(res.status).toBe(400);
    });

    it('401 — rejects unauthenticated requests', async () => {
      const { app } = buildApp();
      const res = await app.request('/me/blocks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ blockedUserId: targetUserId }),
      });

      expect(res.status).toBe(401);
    });

    it('422 — rejects self-block', async () => {
      const { app } = buildApp();
      const res = await app.request('/me/blocks', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${initiatorToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ blockedUserId: initiatorUserId }),
      });

      // blockedUserId === initiatorUserId is not a valid cuid for the actor themselves
      // but is a valid cuid — schema passes, domain rejects with 422.
      expect(res.status).toBe(422);
    });
  });

  describe('DELETE /me/blocks/:blockedUserId', () => {
    it('204 — unblocks the user', async () => {
      const { app } = buildApp();
      const res = await app.request(`/me/blocks/${targetUserId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${initiatorToken}` },
      });

      expect(res.status).toBe(204);

      const found = await db.userBlock.findFirst({
        where: { initiatorUserId, blockedUserId: targetUserId },
      });
      expect(found).toBeNull();
    });

    it('204 — idempotent: unblocking a non-blocked user returns 204', async () => {
      const { app } = buildApp();
      const res = await app.request(`/me/blocks/${otherUserId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${initiatorToken}` },
      });

      expect(res.status).toBe(204);
    });

    it('401 — rejects unauthenticated requests', async () => {
      const { app } = buildApp();
      const res = await app.request(`/me/blocks/${targetUserId}`, {
        method: 'DELETE',
      });

      expect(res.status).toBe(401);
    });
  });

  describe('GET /me/blocks', () => {
    let seedBlockId: string;

    beforeAll(async () => {
      if (!dbUrl) return;
      // Seed a block row directly so the list test doesn't depend on the
      // DELETE test having already unblocked (ordering between sibling
      // describe blocks is not guaranteed to be fully sequential in Vitest
      // when async beforeAll hooks are involved).
      seedBlockId = createId();
      await db.userBlock.upsert({
        where: {
          initiatorUserId_blockedUserId: {
            initiatorUserId,
            blockedUserId: targetUserId,
          },
        },
        create: { id: seedBlockId, initiatorUserId, blockedUserId: targetUserId },
        update: {},
      });
    });

    it('200 — returns paginated list of blocks', async () => {
      const { app } = buildApp();
      const res = await app.request('/me/blocks', {
        method: 'GET',
        headers: { Authorization: `Bearer ${initiatorToken}` },
      });

      expect(res.status).toBe(200);
      const body = (await res.json()) as {
        rows: { blockedUserId: string }[];
        nextCursor: string | null;
      };
      expect(Array.isArray(body.rows)).toBe(true);
      expect(body.rows.some((r) => r.blockedUserId === targetUserId)).toBe(true);
      expect(body.nextCursor).toBeNull();
    });

    it('401 — rejects unauthenticated requests', async () => {
      const { app } = buildApp();
      const res = await app.request('/me/blocks', { method: 'GET' });
      expect(res.status).toBe(401);
    });
  });
});
