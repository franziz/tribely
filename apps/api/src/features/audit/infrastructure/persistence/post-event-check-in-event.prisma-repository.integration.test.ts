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

import type { PostEventCheckInEventEntry } from '../../domain/repositories/post-event-check-in-event.repository.js';
import { PostEventCheckInEventPrismaRepository } from './post-event-check-in-event.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * End-to-end repository test against the Postgres service container (CI) or
 * the local Neon dev branch (`.env`). Skipped when DATABASE_URL is unset so
 * unit-only runs still pass.
 *
 * The suite operates directly on `post_event_check_in_events`. No FK to
 * User / Event / PostEventCheckIn exists (PDPA s25 requirement — rows must
 * outlive the originating records), so no seed data is needed. Each test
 * tracks its own IDs for cleanup.
 */
describe.skipIf(!dbUrl)('PostEventCheckInEventPrismaRepository (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let repo: PostEventCheckInEventPrismaRepository;
  const trackedIds = new Set<string>();

  const buildEntry = (
    overrides: Partial<PostEventCheckInEventEntry> = {},
  ): PostEventCheckInEventEntry => {
    const id = createId();
    trackedIds.add(id);
    return {
      id,
      checkInId: createId(),
      userId: createId(),
      eventId: createId(),
      reason: 'created',
      occurredAt: new Date('2026-01-15T12:00:00Z'),
      requestId: 'req-integration-test',
      recordedAt: new Date('2026-01-15T12:00:01Z'),
      ...overrides,
    };
  };

  beforeAll(() => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    repo = new PostEventCheckInEventPrismaRepository(db);
  });

  beforeEach(async () => {
    if (!dbUrl) return;
    if (trackedIds.size > 0) {
      await db.postEventCheckInEvent.deleteMany({ where: { id: { in: [...trackedIds] } } });
      trackedIds.clear();
    }
  });

  afterAll(async () => {
    if (!dbUrl) return;
    if (trackedIds.size > 0) {
      await db.postEventCheckInEvent
        .deleteMany({ where: { id: { in: [...trackedIds] } } })
        .catch(() => null);
    }
    await db.$disconnect();
  });

  it('record: inserts a row and the fields round-trip correctly', async () => {
    const entry = buildEntry({ requestId: 'req-roundtrip' });

    await runWithContext({ requestId: 'req-roundtrip', actorUserId: null }, () =>
      unitOfWork.run((ctx) => repo.record(entry, ctx)),
    );

    const row = await db.postEventCheckInEvent.findUnique({ where: { id: entry.id } });
    expect(row).not.toBeNull();
    expect(row?.id).toBe(entry.id);
    expect(row?.checkInId).toBe(entry.checkInId);
    expect(row?.userId).toBe(entry.userId);
    expect(row?.eventId).toBe(entry.eventId);
    expect(row?.reason).toBe('created');
    expect(row?.occurredAt.toISOString()).toBe(entry.occurredAt.toISOString());
    expect(row?.requestId).toBe('req-roundtrip');
  });

  it('record: persists null requestId for non-HTTP origins', async () => {
    const entry = buildEntry({ requestId: null });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.postEventCheckInEvent.findUnique({ where: { id: entry.id } });
    expect(row?.requestId).toBeNull();
  });

  it('record: rollback in parent tx leaves no audit row (atomicity contract)', async () => {
    const entry = buildEntry();

    await expect(
      unitOfWork.run(async (ctx) => {
        await repo.record(entry, ctx);
        // Force a rollback by throwing inside the UoW closure.
        throw new Error('forced rollback');
      }),
    ).rejects.toThrow('forced rollback');

    // The audit row must NOT have landed despite the record() call.
    const row = await db.postEventCheckInEvent.findUnique({ where: { id: entry.id } });
    expect(row).toBeNull();

    // Entry was never committed — remove from tracked IDs so cleanup doesn't
    // attempt a DELETE on a non-existent row.
    trackedIds.delete(entry.id);
  });

  it('pruneOlderThan: deletes rows whose occurredAt is before the cutoff and returns count', async () => {
    const entry1 = buildEntry({ occurredAt: new Date('2020-01-01T00:00:00Z') });
    const entry2 = buildEntry({ occurredAt: new Date('2021-06-30T00:00:00Z') });

    await unitOfWork.run(async (ctx) => {
      await repo.record(entry1, ctx);
      await repo.record(entry2, ctx);
    });

    // Prune with a far-future cutoff — both rows should be deleted.
    const count = await unitOfWork.run((ctx) =>
      repo.pruneOlderThan(new Date('9999-01-01T00:00:00Z'), ctx),
    );

    expect(count).toBe(2);

    const remaining = await db.postEventCheckInEvent.findMany({
      where: { id: { in: [entry1.id, entry2.id] } },
    });
    expect(remaining).toHaveLength(0);

    trackedIds.delete(entry1.id);
    trackedIds.delete(entry2.id);
  });

  it('pruneOlderThan: does not delete rows whose occurredAt is on or after the cutoff', async () => {
    const future = buildEntry({ occurredAt: new Date('2099-12-31T00:00:00Z') });

    await unitOfWork.run((ctx) => repo.record(future, ctx));

    const count = await unitOfWork.run((ctx) =>
      repo.pruneOlderThan(new Date('2000-01-01T00:00:00Z'), ctx),
    );

    expect(count).toBe(0);

    const row = await db.postEventCheckInEvent.findUnique({ where: { id: future.id } });
    expect(row).not.toBeNull();
  });
});
