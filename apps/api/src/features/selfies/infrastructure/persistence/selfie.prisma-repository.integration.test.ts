// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { runWithContext } from '@/core/context/request-context.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import { OutboxEventPublisher } from '@/core/events/outbox-event-publisher.js';

import { Selfie } from '../../domain/entities/selfie.js';
import { SelfiePrismaRepository } from './selfie.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * Integration tests for SelfiePrismaRepository against the real Postgres DB
 * (Neon dev branch in dev; service container in CI). Skipped when DATABASE_URL
 * is unset so unit-only runs still pass.
 *
 * Seed: one user per test suite. Each test creates its own Selfie instances
 * and tracks their IDs for cleanup.
 */
describe.skipIf(!dbUrl)('SelfiePrismaRepository (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let publisher: OutboxEventPublisher;
  let repo: SelfiePrismaRepository;

  let userId: string;
  const trackedSelfieIds = new Set<string>();

  const makeSelfie = (
    overrides: {
      status?: 'pending' | 'approved' | 'rejected';
      storageKey?: string | null;
      approvedAt?: Date | null;
      rejectedAt?: Date | null;
    } = {},
  ): Selfie => {
    const id = createId();
    trackedSelfieIds.add(id);
    const now = new Date();
    return Selfie.rehydrate({
      id,
      userId,
      status: overrides.status ?? 'pending',
      storageKey:
        overrides.storageKey !== undefined ? overrides.storageKey : `uploads/${userId}/${id}.jpg`,
      approvedAt: overrides.approvedAt ?? null,
      rejectedAt: overrides.rejectedAt ?? null,
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
    });
  };

  const persist = async (selfie: Selfie): Promise<void> => {
    await runWithContext({ requestId: createId(), actorUserId: userId }, () =>
      unitOfWork.run(async (ctx) => {
        const events = selfie.pullEvents();
        await repo.save(selfie, ctx);
        await publisher.publish(ctx, ...events);
      }),
    );
  };

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    publisher = new OutboxEventPublisher();
    repo = new SelfiePrismaRepository(db);

    userId = createId();
    await db.user.create({
      data: {
        id: userId,
        email: `selfie-repo-${userId}@tri79.test`,
        displayName: 'TRI-79 Test User',
      },
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;
    if (trackedSelfieIds.size > 0) {
      await db.outboxEvent.deleteMany({
        where: { aggregateType: 'Selfie', aggregateId: { in: [...trackedSelfieIds] } },
      });
      await db.selfie.deleteMany({ where: { id: { in: [...trackedSelfieIds] } } });
    }
    await db.user.delete({ where: { id: userId } }).catch(() => null);
    await db.$disconnect();
  });

  describe('save (insert path)', () => {
    it('round-trips a pending selfie: save then findActiveByUserId returns same fields', async () => {
      const selfie = makeSelfie({ status: 'pending' });

      await persist(selfie);

      const loaded = await repo.findActiveByUserId(userId);
      expect(loaded).not.toBeNull();
      if (!loaded) return;
      expect(loaded.id).toBe(selfie.id);
      expect(loaded.userId).toBe(userId);
      expect(loaded.status).toBe('pending');
      expect(loaded.storageKey).toBe(selfie.storageKey);
      expect(loaded.approvedAt).toBeNull();
      expect(loaded.rejectedAt).toBeNull();
      expect(loaded.deletedAt).toBeNull();
    });
  });

  describe('save (update path via markDeleted)', () => {
    it('persists the deleted status, null storageKey, and deletedAt after markDeleted', async () => {
      const selfie = makeSelfie({ status: 'approved', approvedAt: new Date() });
      await persist(selfie);

      const now = new Date();
      selfie.markDeleted(now, 'retention-sweep');
      await persist(selfie);

      // findActiveByUserId should no longer return this selfie
      const active = await repo.findActiveByUserId(userId);
      // Could be null or a different selfie — must NOT be this one
      if (active) {
        expect(active.id).not.toBe(selfie.id);
      }

      // Verify deletion state in DB directly
      const row = await db.selfie.findUnique({ where: { id: selfie.id } });
      expect(row).not.toBeNull();
      if (!row) return;
      expect(row.status).toBe('deleted');
      expect(row.storageKey).toBeNull();
      expect(row.deletedAt).not.toBeNull();
    });
  });

  describe('findActiveByUserId', () => {
    it('returns the most recent non-deleted selfie for the user', async () => {
      // Insert an older pending selfie, then a newer one — should return the newer
      const older = makeSelfie({ status: 'pending' });
      await persist(older);
      // Small delay so createdAt ordering is deterministic
      await new Promise((r) => setTimeout(r, 5));
      const newer = makeSelfie({ status: 'rejected', rejectedAt: new Date() });
      await persist(newer);

      // Both belong to userId. The active check returns latest non-deleted.
      const active = await repo.findActiveByUserId(userId);
      // newer was inserted last so createdAt DESC should return it
      expect(active).not.toBeNull();
      if (!active) return;
      expect(active.id).toBe(newer.id);
    });

    it('returns null when all selfies for the user are deleted', async () => {
      const isolatedUserId = createId();
      await db.user.create({
        data: {
          id: isolatedUserId,
          email: `null-active-${isolatedUserId}@tri79.test`,
          displayName: 'Isolated',
        },
      });

      try {
        const selfieId = createId();
        const now = new Date();
        // Insert directly via Prisma — we want a deleted row, no pullEvents needed
        await db.selfie.create({
          data: {
            id: selfieId,
            userId: isolatedUserId,
            status: 'deleted',
            storageKey: null,
            approvedAt: null,
            rejectedAt: null,
            deletedAt: now,
            createdAt: now,
            updatedAt: now,
          },
        });

        const active = await repo.findActiveByUserId(isolatedUserId);
        expect(active).toBeNull();
      } finally {
        await db.selfie.deleteMany({ where: { userId: isolatedUserId } });
        await db.user.delete({ where: { id: isolatedUserId } }).catch(() => null);
      }
    });
  });

  describe('findEligibleForRetentionSweep', () => {
    it('returns approved selfies where approvedAt is before the cutoff', async () => {
      const past = new Date('2026-01-01T00:00:00Z');
      const cutoff = new Date('2026-04-01T00:00:00Z');
      const isolatedUserId = createId();
      await db.user.create({
        data: {
          id: isolatedUserId,
          email: `sweep-approved-${isolatedUserId}@tri79.test`,
          displayName: 'Sweep',
        },
      });

      try {
        const eligible = await db.selfie.create({
          data: {
            id: createId(),
            userId: isolatedUserId,
            status: 'approved',
            storageKey: 'uploads/test/eligible.jpg',
            approvedAt: past,
            rejectedAt: null,
            deletedAt: null,
            createdAt: past,
            updatedAt: past,
          },
        });

        const results = await repo.findEligibleForRetentionSweep(cutoff);
        const ids = results.map((s) => s.id);
        expect(ids).toContain(eligible.id);
        // All returned selfies must be in an eligible state
        for (const s of results) {
          expect(['approved', 'rejected']).toContain(s.status);
        }
      } finally {
        await db.selfie.deleteMany({ where: { userId: isolatedUserId } });
        await db.user.delete({ where: { id: isolatedUserId } }).catch(() => null);
      }
    });

    it('returns rejected selfies where rejectedAt is before the cutoff', async () => {
      const past = new Date('2026-01-15T00:00:00Z');
      const cutoff = new Date('2026-04-01T00:00:00Z');
      const isolatedUserId = createId();
      await db.user.create({
        data: {
          id: isolatedUserId,
          email: `sweep-rejected-${isolatedUserId}@tri79.test`,
          displayName: 'SweepRej',
        },
      });

      try {
        const eligible = await db.selfie.create({
          data: {
            id: createId(),
            userId: isolatedUserId,
            status: 'rejected',
            storageKey: 'uploads/test/rej.jpg',
            approvedAt: null,
            rejectedAt: past,
            deletedAt: null,
            createdAt: past,
            updatedAt: past,
          },
        });

        const results = await repo.findEligibleForRetentionSweep(cutoff);
        const ids = results.map((s) => s.id);
        expect(ids).toContain(eligible.id);
      } finally {
        await db.selfie.deleteMany({ where: { userId: isolatedUserId } });
        await db.user.delete({ where: { id: isolatedUserId } }).catch(() => null);
      }
    });

    it('does NOT return pending selfies', async () => {
      const cutoff = new Date('2099-01-01T00:00:00Z'); // far-future cutoff catches everything
      const now = new Date();
      const isolatedUserId = createId();
      await db.user.create({
        data: {
          id: isolatedUserId,
          email: `no-pending-${isolatedUserId}@tri79.test`,
          displayName: 'NoPending',
        },
      });

      try {
        const pendingId = createId();
        await db.selfie.create({
          data: {
            id: pendingId,
            userId: isolatedUserId,
            status: 'pending',
            storageKey: 'uploads/test/pending.jpg',
            approvedAt: null,
            rejectedAt: null,
            deletedAt: null,
            createdAt: now,
            updatedAt: now,
          },
        });

        const results = await repo.findEligibleForRetentionSweep(cutoff);
        const ids = results.map((s) => s.id);
        expect(ids).not.toContain(pendingId);
      } finally {
        await db.selfie.deleteMany({ where: { userId: isolatedUserId } });
        await db.user.delete({ where: { id: isolatedUserId } }).catch(() => null);
      }
    });

    it('does NOT return already-deleted selfies', async () => {
      const cutoff = new Date('2099-01-01T00:00:00Z');
      const past = new Date('2026-01-01T00:00:00Z');
      const isolatedUserId = createId();
      await db.user.create({
        data: {
          id: isolatedUserId,
          email: `no-deleted-${isolatedUserId}@tri79.test`,
          displayName: 'NoDeleted',
        },
      });

      try {
        const deletedId = createId();
        await db.selfie.create({
          data: {
            id: deletedId,
            userId: isolatedUserId,
            status: 'deleted',
            storageKey: null,
            approvedAt: past,
            rejectedAt: null,
            deletedAt: past,
            createdAt: past,
            updatedAt: past,
          },
        });

        const results = await repo.findEligibleForRetentionSweep(cutoff);
        const ids = results.map((s) => s.id);
        expect(ids).not.toContain(deletedId);
      } finally {
        await db.selfie.deleteMany({ where: { userId: isolatedUserId } });
        await db.user.delete({ where: { id: isolatedUserId } }).catch(() => null);
      }
    });

    it('does NOT return approved selfies where approvedAt >= cutoff', async () => {
      const future = new Date('2030-01-01T00:00:00Z');
      const cutoff = new Date('2026-04-01T00:00:00Z'); // cutoff is before `future`
      const isolatedUserId = createId();
      await db.user.create({
        data: {
          id: isolatedUserId,
          email: `not-yet-eligible-${isolatedUserId}@tri79.test`,
          displayName: 'NotYet',
        },
      });

      try {
        const notEligibleId = createId();
        await db.selfie.create({
          data: {
            id: notEligibleId,
            userId: isolatedUserId,
            status: 'approved',
            storageKey: 'uploads/test/not-yet.jpg',
            approvedAt: future,
            rejectedAt: null,
            deletedAt: null,
            createdAt: future,
            updatedAt: future,
          },
        });

        const results = await repo.findEligibleForRetentionSweep(cutoff);
        const ids = results.map((s) => s.id);
        expect(ids).not.toContain(notEligibleId);
      } finally {
        await db.selfie.deleteMany({ where: { userId: isolatedUserId } });
        await db.user.delete({ where: { id: isolatedUserId } }).catch(() => null);
      }
    });
  });
});
