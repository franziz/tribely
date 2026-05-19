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

import { PostEventCheckIn } from '../../domain/entities/post-event-check-in.js';
import { PostEventCheckInPrismaRepository } from './post-event-check-in.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * Integration tests for PostEventCheckInPrismaRepository.
 *
 * The @@unique([userId, eventId]) constraint means each (user, event) pair can
 * have at most one check-in. To keep tests hermetic, each test that creates a
 * check-in uses a helper that provisions its own fresh attendee user and event.
 * Only the shared host user is re-used across tests.
 */
describe.skipIf(!dbUrl)('PostEventCheckInPrismaRepository (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let publisher: OutboxEventPublisher;
  let repo: PostEventCheckInPrismaRepository;

  /** Shared host — FK for hostUserId on every check-in. */
  let hostUserId: string;

  /** Track all provisioned resource ids for cleanup. */
  const provisioned = {
    checkInIds: new Set<string>(),
    userIds: new Set<string>(),
    eventIds: new Set<string>(),
  };

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /** Provision a fresh attendee user. Registered in provisioned.userIds. */
  const makeUser = async (tag = 'attendee'): Promise<string> => {
    const id = createId();
    await db.user.create({
      data: { id, email: `${tag}-${id}@tri29.test`, displayName: `${tag}-${id.slice(0, 6)}` },
    });
    provisioned.userIds.add(id);
    return id;
  };

  /** Provision a fresh parent event. Registered in provisioned.eventIds. */
  const makeEvent = async (hostId = hostUserId): Promise<string> => {
    const id = createId();
    const now = new Date();
    await db.event.create({
      data: {
        id,
        hostUserId: hostId,
        title: `tri29-event-${id.slice(0, 6)}`,
        description: null,
        venueAddress: '18 Raffles Quay, Singapore',
        venueCity: 'Singapore',
        venueLatitude: 1.2806,
        venueLongitude: 103.8504,
        startsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
        endsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
        capacity: 6,
        category: 'food',
        costSplit: 'own',
        approvalMode: 'manual',
        status: 'published',
        cancellationReason: null,
        createdAt: now,
        updatedAt: now,
      },
    });
    provisioned.eventIds.add(id);
    return id;
  };

  /** Build (in memory only) a PostEventCheckIn aggregate for a given user+event. */
  const buildCheckIn = (userId: string, eventId: string): PostEventCheckIn => {
    const id = createId();
    provisioned.checkInIds.add(id);
    return PostEventCheckIn.create({ id, userId, eventId, hostUserId, now: new Date() });
  };

  /** Persist a check-in (save + publish events) inside a UoW. */
  const persist = async (chk: PostEventCheckIn, actorId = hostUserId): Promise<void> => {
    await runWithContext({ requestId: createId(), actorUserId: actorId }, () =>
      unitOfWork.run(async (ctx) => {
        const pending = chk.pullEvents();
        await repo.save(chk, ctx);
        await publisher.publish(ctx, ...pending);
      }),
    );
  };

  // ---------------------------------------------------------------------------
  // Setup / teardown
  // ---------------------------------------------------------------------------

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    publisher = new OutboxEventPublisher();
    repo = new PostEventCheckInPrismaRepository(db);

    hostUserId = createId();
    await db.user.create({
      data: { id: hostUserId, email: `host-${hostUserId}@tri29.test`, displayName: 'TRI-29 Host' },
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // Clean up outbox rows for check-ins we created.
    if (provisioned.checkInIds.size > 0) {
      await db.outboxEvent
        .deleteMany({
          where: {
            aggregateType: 'PostEventCheckIn',
            aggregateId: { in: [...provisioned.checkInIds] },
          },
        })
        .catch(() => null);
    }
    // Events cascade-delete check-in rows.
    for (const eid of provisioned.eventIds) {
      await db.event.delete({ where: { id: eid } }).catch(() => null);
      await db.outboxEvent
        .deleteMany({ where: { aggregateType: 'Event', aggregateId: eid } })
        .catch(() => null);
    }
    // Delete provisioned attendee users.
    if (provisioned.userIds.size > 0) {
      await db.user.deleteMany({ where: { id: { in: [...provisioned.userIds] } } }).catch(() => null);
    }
    // Delete host last (cascade would have handled owned events, but we already
    // deleted them explicitly above).
    await db.user.delete({ where: { id: hostUserId } }).catch(() => null);
    await db.$disconnect();
  });

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  it('round-trips a saved pending check-in (save → findById preserves all fields)', async () => {
    const userId = await makeUser();
    const eventId = await makeEvent();
    const chk = buildCheckIn(userId, eventId);
    await persist(chk, userId);

    const loaded = await repo.findById(chk.id);
    expect(loaded).not.toBeNull();
    if (!loaded) return;
    expect(loaded.id).toBe(chk.id);
    expect(loaded.userId).toBe(userId);
    expect(loaded.eventId).toBe(eventId);
    expect(loaded.hostUserId).toBe(hostUserId);
    expect(loaded.status).toBe('pending');
    expect(loaded.acknowledgedAt).toBeNull();
    expect(loaded.flaggedAt).toBeNull();
    expect(loaded.reportBody).toBeNull();
    expect(loaded.resolvedAt).toBeNull();
  });

  it('findByUserAndEvent returns the check-in for the (userId, eventId) pair', async () => {
    const userId = await makeUser();
    const eventId = await makeEvent();
    const chk = buildCheckIn(userId, eventId);
    await persist(chk, userId);

    const found = await repo.findByUserAndEvent(userId, eventId);
    expect(found?.id).toBe(chk.id);
  });

  it('findByUserAndEvent returns null for unknown pair', async () => {
    expect(await repo.findByUserAndEvent(createId(), createId())).toBeNull();
  });

  it('persists state transition: pending → ok after acknowledge', async () => {
    const userId = await makeUser();
    const eventId = await makeEvent();
    const chk = buildCheckIn(userId, eventId);
    await persist(chk, userId);

    const loaded = await repo.findById(chk.id);
    if (!loaded) throw new Error('not found');
    const ackTime = new Date();
    loaded.acknowledge({ now: ackTime });
    await persist(loaded, userId);

    const reloaded = await repo.findById(chk.id);
    expect(reloaded?.status).toBe('ok');
    expect(reloaded?.acknowledgedAt?.getTime()).toBe(ackTime.getTime());
  });

  it('persists state transition: pending → flagged after flag', async () => {
    const userId = await makeUser();
    const eventId = await makeEvent();
    const chk = buildCheckIn(userId, eventId);
    await persist(chk, userId);

    const loaded = await repo.findById(chk.id);
    if (!loaded) throw new Error('not found');
    const flagTime = new Date();
    loaded.flag({ reportBody: 'Unsafe experience', now: flagTime });
    await persist(loaded, userId);

    const reloaded = await repo.findById(chk.id);
    expect(reloaded?.status).toBe('flagged');
    expect(reloaded?.flaggedAt?.getTime()).toBe(flagTime.getTime());
    expect(reloaded?.reportBody).toBe('Unsafe experience');
  });

  describe('unique pair invariant', () => {
    it('rejects a second check-in for the same (userId, eventId)', async () => {
      const userId = await makeUser();
      const eventId = await makeEvent();
      const chk1 = buildCheckIn(userId, eventId);
      await persist(chk1, userId);

      // Build a second check-in for the same user+event with a fresh id.
      const secondId = createId();
      provisioned.checkInIds.add(secondId);
      const chk2 = PostEventCheckIn.create({
        id: secondId,
        userId,
        eventId,
        hostUserId,
        now: new Date(),
      });
      chk2.pullEvents(); // discard — we only test the DB constraint

      await expect(persist(chk2, userId)).rejects.toThrow();
    });
  });

  describe('listPendingForUser', () => {
    it('returns pending rows for the user and excludes non-pending ones', async () => {
      const userId = await makeUser('list-pending');
      const eventIdPending = await makeEvent();
      const eventIdAcked = await makeEvent();

      const pendingChk = buildCheckIn(userId, eventIdPending);
      const ackedChk = buildCheckIn(userId, eventIdAcked);
      await persist(pendingChk, userId);
      await persist(ackedChk, userId);

      // Acknowledge the second check-in — should no longer appear in listPending.
      const loaded = await repo.findById(ackedChk.id);
      if (!loaded) throw new Error('not found');
      loaded.acknowledge({ now: new Date() });
      await persist(loaded, userId);

      const pending = await repo.listPendingForUser(userId);
      expect(pending.every((c) => c.status === 'pending')).toBe(true);
      expect(pending.some((c) => c.id === pendingChk.id)).toBe(true);
      expect(pending.find((c) => c.id === ackedChk.id)).toBeUndefined();
    });
  });

  describe('listForRetentionSweep', () => {
    it('returns rows matching status + olderThan filter', async () => {
      const userId = await makeUser('sweep');
      const eventId = await makeEvent();
      const chk = buildCheckIn(userId, eventId);
      await persist(chk, userId);

      // Use a future cut-off so the row we just created is included.
      const cutoff = new Date(Date.now() + 60_000);
      const results = await repo.listForRetentionSweep({ status: 'pending', olderThan: cutoff });
      expect(results.some((c) => c.id === chk.id)).toBe(true);
    });

    it('excludes rows newer than olderThan', async () => {
      const userId = await makeUser('sweep-excl');
      const eventId = await makeEvent();
      const chk = buildCheckIn(userId, eventId);
      await persist(chk, userId);

      // Use a past cut-off — row was just created so it should not match.
      const cutoff = new Date(Date.now() - 60_000);
      const results = await repo.listForRetentionSweep({ status: 'pending', olderThan: cutoff });
      expect(results.find((c) => c.id === chk.id)).toBeUndefined();
    });
  });

  describe('deleteById', () => {
    it('removes the check-in row', async () => {
      const userId = await makeUser('delete');
      const eventId = await makeEvent();
      const chk = buildCheckIn(userId, eventId);
      await persist(chk, userId);

      await runWithContext({ requestId: createId(), actorUserId: hostUserId }, () =>
        unitOfWork.run(async (ctx) => {
          await repo.deleteById(chk.id, ctx);
        }),
      );

      expect(await repo.findById(chk.id)).toBeNull();
    });
  });

  describe('pseudonymiseForUser', () => {
    it('updates userId for attendee role', async () => {
      const userId = await makeUser('pseudo-src');
      const eventId = await makeEvent();
      const chk = buildCheckIn(userId, eventId);
      await persist(chk, userId);

      const pseudoId = await makeUser('pseudo-dest');

      const count = await runWithContext(
        { requestId: createId(), actorUserId: hostUserId },
        () =>
          unitOfWork.run(async (ctx) =>
            repo.pseudonymiseForUser(
              { userId, pseudonymUserId: pseudoId, role: 'attendee' },
              ctx,
            ),
          ),
      );
      expect(count).toBeGreaterThanOrEqual(1);
      const row = await db.postEventCheckIn.findUnique({ where: { id: chk.id } });
      expect(row?.userId).toBe(pseudoId);
    });
  });

  it('returns null for unknown id', async () => {
    expect(await repo.findById(createId())).toBeNull();
  });
});
