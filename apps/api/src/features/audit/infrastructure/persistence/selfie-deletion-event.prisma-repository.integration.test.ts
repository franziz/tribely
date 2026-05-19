// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { runWithContext } from '@/core/context/request-context.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';

import type { SelfieDeletionEventRecord } from '../../domain/repositories/selfie-deletion-event.repository.js';
import { SelfieDeletionEventPrismaRepository } from './selfie-deletion-event.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * End-to-end repository test against the Postgres service container (CI) or
 * the local Neon dev branch (`.env`). Skipped when DATABASE_URL is unset so
 * unit-only runs still pass.
 *
 * The suite operates directly on `selfie_deletion_events`. No FK to User
 * exists (PDPA s25 requirement — rows must outlive the user record), so no
 * seed user is needed. Each test tracks its own IDs for cleanup.
 */
describe.skipIf(!dbUrl)('SelfieDeletionEventPrismaRepository (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let repo: SelfieDeletionEventPrismaRepository;
  const trackedIds = new Set<string>();

  const buildRecord = (
    overrides: Partial<SelfieDeletionEventRecord> = {},
  ): SelfieDeletionEventRecord => {
    const id = createId();
    trackedIds.add(id);
    return {
      id,
      userId: createId(),
      selfieId: createId(),
      reason: 'user-request',
      deletedAt: new Date('2026-01-15T12:00:00Z'),
      requestId: 'req-integration-test',
      recordedAt: new Date('2026-01-15T12:00:01Z'),
      ...overrides,
    };
  };

  beforeAll(() => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    repo = new SelfieDeletionEventPrismaRepository(db);
  });

  beforeEach(async () => {
    if (!dbUrl) return;
    // Clean any rows left by a previous test in this run — guards against
    // test ordering issues. Cleanup at afterAll handles the full teardown.
    if (trackedIds.size > 0) {
      await db.selfieDeletionEvent.deleteMany({ where: { id: { in: [...trackedIds] } } });
      trackedIds.clear();
    }
  });

  afterAll(async () => {
    if (!dbUrl) return;
    if (trackedIds.size > 0) {
      await db.selfieDeletionEvent
        .deleteMany({ where: { id: { in: [...trackedIds] } } })
        .catch(() => null);
    }
    await db.$disconnect();
  });

  it('record: inserts a row and the fields round-trip correctly', async () => {
    const entry = buildRecord({ requestId: 'req-roundtrip' });

    await runWithContext({ requestId: 'req-roundtrip', actorUserId: null }, () =>
      unitOfWork.run((ctx) => repo.record(entry, ctx)),
    );

    const row = await db.selfieDeletionEvent.findUnique({ where: { id: entry.id } });
    expect(row).not.toBeNull();
    expect(row?.id).toBe(entry.id);
    expect(row?.userId).toBe(entry.userId);
    expect(row?.selfieId).toBe(entry.selfieId);
    expect(row?.reason).toBe('user-request');
    expect(row?.deletedAt.toISOString()).toBe(entry.deletedAt.toISOString());
    expect(row?.requestId).toBe('req-roundtrip');
  });

  it('record: persists null requestId for non-HTTP origins', async () => {
    const entry = buildRecord({ requestId: null });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.selfieDeletionEvent.findUnique({ where: { id: entry.id } });
    expect(row?.requestId).toBeNull();
  });

  it('pruneOlderThan: deletes rows whose deletedAt is before the cutoff and returns count', async () => {
    // Insert two rows — both with deletedAt well in the past
    const entry1 = buildRecord({ deletedAt: new Date('2020-01-01T00:00:00Z') });
    const entry2 = buildRecord({ deletedAt: new Date('2021-06-30T00:00:00Z') });

    await unitOfWork.run(async (ctx) => {
      await repo.record(entry1, ctx);
      await repo.record(entry2, ctx);
    });

    // Prune with a far-future cutoff — both rows should be deleted
    const count = await unitOfWork.run((ctx) =>
      repo.pruneOlderThan(new Date('9999-01-01T00:00:00Z'), ctx),
    );

    expect(count).toBe(2);

    // Verify table is empty for these ids
    const remaining = await db.selfieDeletionEvent.findMany({
      where: { id: { in: [entry1.id, entry2.id] } },
    });
    expect(remaining).toHaveLength(0);

    // Prevent beforeEach from trying to delete already-deleted rows
    trackedIds.delete(entry1.id);
    trackedIds.delete(entry2.id);
  });

  it('pruneOlderThan: does not delete rows whose deletedAt is on or after the cutoff', async () => {
    const future = buildRecord({ deletedAt: new Date('2099-12-31T00:00:00Z') });

    await unitOfWork.run((ctx) => repo.record(future, ctx));

    // Prune with a cutoff in the past — nothing should be deleted
    const count = await unitOfWork.run((ctx) =>
      repo.pruneOlderThan(new Date('2000-01-01T00:00:00Z'), ctx),
    );

    expect(count).toBe(0);

    // Row still exists
    const row = await db.selfieDeletionEvent.findUnique({ where: { id: future.id } });
    expect(row).not.toBeNull();
  });
});
