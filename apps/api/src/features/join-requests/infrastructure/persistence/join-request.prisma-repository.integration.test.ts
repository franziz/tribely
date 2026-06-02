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
import { AppError } from '@/core/errors/app-error.js';
import { OutboxEventPublisher } from '@/core/events/outbox-event-publisher.js';

import { JoinRequest, type JoinRequestEventSnapshot } from '../../domain/entities/join-request.js';
import { JoinRequestPrismaRepository } from './join-request.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * End-to-end repository test against the Postgres service container (CI) or
 * the local Neon dev branch (`.env`). Skipped when DATABASE_URL is unset so
 * unit-only runs still pass.
 *
 * The suite seeds:
 *  - a host user (parent of every Event row)
 *  - a parent Event (FK target for every JoinRequest row)
 *  - a pool of requester users (FK target for the `requesterUserId` column)
 *
 * Each test that triggers events wraps the work in a deterministic
 * AsyncLocalStorage frame so `OutboxEventPublisher` doesn't WARN about a
 * missing context. We clean tracked outbox rows + the parent Event + the
 * host + requesters at the end (the Event cascade-deletes join_requests).
 */
describe.skipIf(!dbUrl)('JoinRequestPrismaRepository (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let publisher: OutboxEventPublisher;
  let repo: JoinRequestPrismaRepository;

  let hostUserId: string;
  let parentEventId: string;
  const requesterIds: string[] = [];
  const trackedJoinRequestIds = new Set<string>();

  const eventSnapshot = (): JoinRequestEventSnapshot => ({
    startsAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    endsAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
    venue: {
      address: '18 Raffles Quay, Singapore',
      city: 'Singapore',
      latitude: 1.2806,
      longitude: 103.8504,
    },
    hostUserId,
  });

  const buildRequester = async (): Promise<string> => {
    const id = createId();
    await db.user.create({
      data: { id, email: `requester-${id}@tri20.test`, displayName: `R-${id.slice(0, 6)}` },
    });
    requesterIds.push(id);
    return id;
  };

  const buildJoinRequest = (
    requesterUserId: string,
    overrides: { eventId?: string; autoApprove?: boolean } = {},
  ): JoinRequest => {
    const id = createId();
    trackedJoinRequestIds.add(id);
    const jr = JoinRequest.request({
      id,
      eventId: overrides.eventId ?? parentEventId,
      requesterUserId,
      now: new Date(),
      autoApprove: overrides.autoApprove ?? false,
      hostUserId,
      eventSnapshot: eventSnapshot(),
    });
    return jr;
  };

  const persist = async (jr: JoinRequest, ctxLabelActor = hostUserId): Promise<void> => {
    await runWithContext({ requestId: createId(), actorUserId: ctxLabelActor }, () =>
      unitOfWork.run(async (ctx) => {
        const pending = jr.pullEvents();
        await repo.save(jr, ctx);
        await publisher.publish(ctx, ...pending);
      }),
    );
  };

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    publisher = new OutboxEventPublisher();
    repo = new JoinRequestPrismaRepository(db);

    hostUserId = createId();
    await db.user.create({
      data: { id: hostUserId, email: `host-${hostUserId}@tri20.test`, displayName: 'TRI-20 Host' },
    });

    parentEventId = createId();
    const now = new Date();
    await db.event.create({
      data: {
        id: parentEventId,
        hostUserId,
        title: 'TRI-20 Parent Event',
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
  });

  afterAll(async () => {
    if (!dbUrl) return;
    if (trackedJoinRequestIds.size > 0) {
      await db.outboxEvent.deleteMany({
        where: {
          aggregateType: 'JoinRequest',
          aggregateId: { in: [...trackedJoinRequestIds] },
        },
      });
    }
    // Parent Event cascade-deletes join_requests rows; outbox is independent.
    await db.event.delete({ where: { id: parentEventId } }).catch(() => null);
    await db.outboxEvent
      .deleteMany({ where: { aggregateType: 'Event', aggregateId: parentEventId } })
      .catch(() => null);
    if (requesterIds.length > 0) {
      await db.user.deleteMany({ where: { id: { in: requesterIds } } });
    }
    await db.user.delete({ where: { id: hostUserId } }).catch(() => null);
    await db.$disconnect();
  });

  it('round-trips a saved pending request (save → findById preserves all fields incl. null decision)', async () => {
    const requesterId = await buildRequester();
    const jr = buildJoinRequest(requesterId);

    await persist(jr, requesterId);

    const loaded = await repo.findById(jr.id);
    expect(loaded).not.toBeNull();
    if (!loaded) return;
    expect(loaded.id).toBe(jr.id);
    expect(loaded.eventId).toBe(parentEventId);
    expect(loaded.requesterUserId).toBe(requesterId);
    expect(loaded.status).toBe('pending');
    expect(loaded.decidedAt).toBeNull();
    expect(loaded.decidedByUserId).toBeNull();
    expect(loaded.decisionReason).toBeNull();
    expect(loaded.requestedAt.getTime()).toBe(jr.requestedAt.getTime());
  });

  it('persists state transition: pending → approved (rehydrate, approve, save reflects new state)', async () => {
    const requesterId = await buildRequester();
    const jr = buildJoinRequest(requesterId);
    await persist(jr, requesterId);

    const loaded = await repo.findById(jr.id);
    expect(loaded?.status).toBe('pending');
    if (!loaded) return;
    const approvalTime = new Date();
    loaded.approve({ by: hostUserId, now: approvalTime, eventSnapshot: eventSnapshot() });
    await persist(loaded, hostUserId);

    const reloaded = await repo.findById(jr.id);
    expect(reloaded?.status).toBe('approved');
    expect(reloaded?.decidedAt?.getTime()).toBe(approvalTime.getTime());
    expect(reloaded?.decidedByUserId).toBe(hostUserId);
    expect(reloaded?.decisionReason).toBeNull();
  });

  describe('findActiveByEventAndRequester', () => {
    it('returns the pending row', async () => {
      const requesterId = await buildRequester();
      const jr = buildJoinRequest(requesterId);
      await persist(jr, requesterId);

      const active = await repo.findActiveByEventAndRequester(parentEventId, requesterId);
      expect(active).not.toBeNull();
      expect(active?.id).toBe(jr.id);
      expect(active?.status).toBe('pending');
    });

    it('returns the approved row', async () => {
      const requesterId = await buildRequester();
      const jr = buildJoinRequest(requesterId);
      await persist(jr, requesterId);
      const loaded = await repo.findById(jr.id);
      loaded?.approve({ by: hostUserId, now: new Date(), eventSnapshot: eventSnapshot() });
      if (loaded) await persist(loaded, hostUserId);

      const active = await repo.findActiveByEventAndRequester(parentEventId, requesterId);
      expect(active?.id).toBe(jr.id);
      expect(active?.status).toBe('approved');
    });

    it('does NOT return a rejected row', async () => {
      const requesterId = await buildRequester();
      const jr = buildJoinRequest(requesterId);
      await persist(jr, requesterId);
      const loaded = await repo.findById(jr.id);
      loaded?.reject({ by: hostUserId, reason: 'Capacity reached', now: new Date() });
      if (loaded) await persist(loaded, hostUserId);

      const active = await repo.findActiveByEventAndRequester(parentEventId, requesterId);
      expect(active).toBeNull();
    });

    it('does NOT return a cancelled row', async () => {
      const requesterId = await buildRequester();
      const jr = buildJoinRequest(requesterId);
      await persist(jr, requesterId);
      const loaded = await repo.findById(jr.id);
      loaded?.cancelByRequester(new Date());
      if (loaded) await persist(loaded, requesterId);

      const active = await repo.findActiveByEventAndRequester(parentEventId, requesterId);
      expect(active).toBeNull();
    });
  });

  it('countApproved (inside UnitOfWork.run) tallies only approved rows', async () => {
    // Create a fresh parent event so the count is hermetic relative to other
    // tests in the suite.
    const localEventId = createId();
    const now = new Date();
    await db.event.create({
      data: {
        id: localEventId,
        hostUserId,
        title: 'countApproved scope event',
        description: null,
        venueAddress: '1 Raffles Pl, Singapore',
        venueCity: 'Singapore',
        venueLatitude: 1.2843,
        venueLongitude: 103.8513,
        startsAt: new Date(now.getTime() + 8 * 24 * 60 * 60 * 1000),
        endsAt: new Date(now.getTime() + 8 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
        capacity: 10,
        category: 'food',
        costSplit: 'own',
        approvalMode: 'manual',
        status: 'published',
        cancellationReason: null,
        createdAt: now,
        updatedAt: now,
      },
    });

    try {
      // 2 approved, 1 pending, 1 rejected, 1 cancelled — countApproved must return 2.
      const r1 = await buildRequester();
      const r2 = await buildRequester();
      const r3 = await buildRequester();
      const r4 = await buildRequester();
      const r5 = await buildRequester();

      const jr1 = buildJoinRequest(r1, { eventId: localEventId, autoApprove: true });
      const jr2 = buildJoinRequest(r2, { eventId: localEventId, autoApprove: true });
      const jr3 = buildJoinRequest(r3, { eventId: localEventId });
      const jr4 = buildJoinRequest(r4, { eventId: localEventId });
      const jr5 = buildJoinRequest(r5, { eventId: localEventId });

      await persist(jr1, r1);
      await persist(jr2, r2);
      await persist(jr3, r3);
      await persist(jr4, r4);
      await persist(jr5, r5);

      const reloaded4 = await repo.findById(jr4.id);
      reloaded4?.reject({ by: hostUserId, reason: 'No fit', now: new Date() });
      if (reloaded4) await persist(reloaded4, hostUserId);

      const reloaded5 = await repo.findById(jr5.id);
      reloaded5?.cancelByRequester(new Date());
      if (reloaded5) await persist(reloaded5, r5);

      const count = await runWithContext({ requestId: createId(), actorUserId: hostUserId }, () =>
        unitOfWork.run(async (ctx) => {
          return repo.countApproved(localEventId, ctx);
        }),
      );
      expect(count).toBe(2);
    } finally {
      await db.outboxEvent
        .deleteMany({ where: { aggregateType: 'Event', aggregateId: localEventId } })
        .catch(() => null);
      await db.event.delete({ where: { id: localEventId } }).catch(() => null);
    }
  });

  describe('partial unique index enforcement', () => {
    it('rejects a second active request for the same (event, requester) with AppError CONFLICT + subcode ACTIVE_REQUEST_EXISTS', async () => {
      const requesterId = await buildRequester();
      const first = buildJoinRequest(requesterId);
      await persist(first, requesterId);

      // The second insert uses a NEW id but the same (eventId, requesterUserId)
      // while `first` is still pending — the partial unique index must fire.
      const second = buildJoinRequest(requesterId);

      await expect(persist(second, requesterId)).rejects.toMatchObject({
        name: 'AppError',
        code: 'CONFLICT',
        status: 409,
        details: { subcode: 'ACTIVE_REQUEST_EXISTS' },
      });
    });

    it('after rejection, the user can re-request (terminal status releases the partial unique slot)', async () => {
      const requesterId = await buildRequester();
      const first = buildJoinRequest(requesterId);
      await persist(first, requesterId);
      const reloaded = await repo.findById(first.id);
      reloaded?.reject({ by: hostUserId, reason: 'Try again later', now: new Date() });
      if (reloaded) await persist(reloaded, hostUserId);

      const reRequest = buildJoinRequest(requesterId);
      await expect(persist(reRequest, requesterId)).resolves.toBeUndefined();
      const reloadedNew = await repo.findById(reRequest.id);
      expect(reloadedNew?.status).toBe('pending');
    });

    it('after cancellation, the user can re-request (terminal status releases the partial unique slot)', async () => {
      const requesterId = await buildRequester();
      const first = buildJoinRequest(requesterId);
      await persist(first, requesterId);
      const reloaded = await repo.findById(first.id);
      reloaded?.cancelByRequester(new Date());
      if (reloaded) await persist(reloaded, requesterId);

      const reRequest = buildJoinRequest(requesterId);
      await expect(persist(reRequest, requesterId)).resolves.toBeUndefined();
      const reloadedNew = await repo.findById(reRequest.id);
      expect(reloadedNew?.status).toBe('pending');
    });
  });

  describe('findByEvent', () => {
    it('returns all rows for an event ordered by requestedAt asc when no filter is provided', async () => {
      // Isolate this test on a fresh parent event so the assertions can rely
      // on the entire result set being the rows we created here.
      const localEventId = createId();
      const now = new Date();
      await db.event.create({
        data: {
          id: localEventId,
          hostUserId,
          title: 'findByEvent scope event',
          description: null,
          venueAddress: '1 Marina Blvd, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.2792,
          venueLongitude: 103.8543,
          startsAt: new Date(now.getTime() + 9 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() + 9 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
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
      try {
        const r1 = await buildRequester();
        const r2 = await buildRequester();
        const r3 = await buildRequester();
        const jr1 = buildJoinRequest(r1, { eventId: localEventId });
        await persist(jr1, r1);
        // Force perceptible ordering — Postgres timestamp(3) is millisecond
        // precision; one millisecond gap is enough but we use 10 to be safe
        // on systems with coarser clocks.
        await new Promise((resolve) => setTimeout(resolve, 10));
        const jr2 = buildJoinRequest(r2, { eventId: localEventId });
        await persist(jr2, r2);
        await new Promise((resolve) => setTimeout(resolve, 10));
        const jr3 = buildJoinRequest(r3, { eventId: localEventId });
        await persist(jr3, r3);

        const list = await repo.findByEvent(localEventId, {});
        expect(list.map((j) => j.id)).toEqual([jr1.id, jr2.id, jr3.id]);
      } finally {
        await db.outboxEvent
          .deleteMany({ where: { aggregateType: 'Event', aggregateId: localEventId } })
          .catch(() => null);
        await db.event.delete({ where: { id: localEventId } }).catch(() => null);
      }
    });

    it('filters by requesterUserId', async () => {
      const localEventId = createId();
      const now = new Date();
      await db.event.create({
        data: {
          id: localEventId,
          hostUserId,
          title: 'findByEvent filter scope event',
          description: null,
          venueAddress: '2 Marina Blvd, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.2793,
          venueLongitude: 103.8544,
          startsAt: new Date(now.getTime() + 10 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() + 10 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
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
      try {
        const targetRequester = await buildRequester();
        const otherRequester = await buildRequester();
        const targetJr = buildJoinRequest(targetRequester, { eventId: localEventId });
        const otherJr = buildJoinRequest(otherRequester, { eventId: localEventId });
        await persist(targetJr, targetRequester);
        await persist(otherJr, otherRequester);

        const filtered = await repo.findByEvent(localEventId, {
          requesterUserId: targetRequester,
        });
        expect(filtered).toHaveLength(1);
        expect(filtered[0]?.id).toBe(targetJr.id);
      } finally {
        await db.outboxEvent
          .deleteMany({ where: { aggregateType: 'Event', aggregateId: localEventId } })
          .catch(() => null);
        await db.event.delete({ where: { id: localEventId } }).catch(() => null);
      }
    });
  });

  it('returns null for an unknown id', async () => {
    expect(await repo.findById(createId())).toBeNull();
  });

  it('rejects saving a request whose event does not exist (FK guard)', async () => {
    const requesterId = await buildRequester();
    const orphan = JoinRequest.request({
      id: createId(),
      eventId: createId(), // non-existent event
      requesterUserId: requesterId,
      now: new Date(),
      autoApprove: false,
      hostUserId,
      eventSnapshot: eventSnapshot(),
    });
    // Pull events so the (failed) save doesn't leave them queued on the
    // aggregate — keeps the test hermetic.
    orphan.pullEvents();
    await expect(repo.save(orphan)).rejects.toThrow();
  });

  it('AppError thrown from P2002 surfaces as an AppError instance (not a raw PrismaClientKnownRequestError)', async () => {
    // Defensive: the use case relies on `instanceof AppError` in the HTTP
    // error mapper, so confirm the translation happens here rather than
    // leaking the Prisma type up.
    const requesterId = await buildRequester();
    const first = buildJoinRequest(requesterId);
    await persist(first, requesterId);
    const second = buildJoinRequest(requesterId);

    await expect(persist(second, requesterId)).rejects.toBeInstanceOf(AppError);
  });

  describe('pseudonymiseAuthorForUser', () => {
    it('rewrites requesterUserId for matched rows, leaves other users untouched, returns correct count', async () => {
      // Seed: 3 requesters × varying row counts per requester. Pseudonymise
      // requester A only. Asserts: A rows rewritten, B and C rows untouched,
      // returned count matches A's row count.
      const requesterA = await buildRequester();
      const requesterB = await buildRequester();
      const requesterC = await buildRequester();

      const jrA1 = buildJoinRequest(requesterA);
      const jrA2 = buildJoinRequest(requesterA, { eventId: parentEventId });
      // A has 2 rows BUT partial unique index prevents two active rows on the
      // same (eventId, requesterUserId). We reject jrA2 first so both can coexist.
      await persist(jrA1, requesterA);
      // Reject jrA1 so the index slot is freed, then create jrA2.
      const loadedA1 = await repo.findById(jrA1.id);
      loadedA1?.reject({ by: hostUserId, reason: 'Test pseudonymise', now: new Date() });
      if (loadedA1) await persist(loadedA1, hostUserId);
      await persist(jrA2, requesterA);

      const jrB = buildJoinRequest(requesterB);
      const jrC = buildJoinRequest(requesterC);
      await persist(jrB, requesterB);
      await persist(jrC, requesterC);

      const pseudonym = createId();
      const count = await runWithContext({ requestId: createId(), actorUserId: requesterA }, () =>
        unitOfWork.run(async (ctx) => repo.pseudonymiseAuthorForUser(requesterA, pseudonym, ctx)),
      );

      // 2 rows for requester A.
      expect(count).toBe(2);

      // Requester A rows rewritten to pseudonym.
      const aRows = await db.joinRequest.findMany({
        where: { id: { in: [jrA1.id, jrA2.id] } },
      });
      expect(aRows.every((r) => r.requesterUserId === pseudonym)).toBe(true);

      // Requester B and C rows untouched.
      const bRow = await db.joinRequest.findUnique({ where: { id: jrB.id } });
      expect(bRow?.requesterUserId).toBe(requesterB);
      const cRow = await db.joinRequest.findUnique({ where: { id: jrC.id } });
      expect(cRow?.requesterUserId).toBe(requesterC);
    });

    it('returns 0 when no rows match the userId', async () => {
      const count = await runWithContext({ requestId: createId(), actorUserId: createId() }, () =>
        unitOfWork.run(async (ctx) => repo.pseudonymiseAuthorForUser(createId(), createId(), ctx)),
      );
      expect(count).toBe(0);
    });
  });

  describe('findLatestByRequesterAndEvent', () => {
    it('returns null when no prior JR exists for the (requester, event) pair', async () => {
      const requesterId = await buildRequester();
      const result = await repo.findLatestByRequesterAndEvent(requesterId, parentEventId);
      expect(result).toBeNull();
    });

    it('returns the most-recent JR by requestedAt when multiple exist for the same pair', async () => {
      // Seed two JRs for the same (requester, event) pair. The partial unique
      // index only blocks concurrent ACTIVE rows, so we reject the first before
      // inserting the second.
      const requesterId = await buildRequester();

      const first = buildJoinRequest(requesterId);
      await persist(first, requesterId);
      const loadedFirst = await repo.findById(first.id);
      loadedFirst?.reject({ by: hostUserId, reason: 'Not a good fit', now: new Date() });
      if (loadedFirst) await persist(loadedFirst, hostUserId);

      // Brief pause so requestedAt differs.
      await new Promise((resolve) => setTimeout(resolve, 10));

      const second = buildJoinRequest(requesterId);
      await persist(second, requesterId);

      const latest = await repo.findLatestByRequesterAndEvent(requesterId, parentEventId);
      expect(latest).not.toBeNull();
      expect(latest?.id).toBe(second.id);
    });
  });

  it('save + findById round-trips a removed_by_host aggregate intact (status, decisionReason, decidedAt, decidedByUserId)', async () => {
    const requesterId = await buildRequester();

    // Create → approve → removeByHost
    const jr = buildJoinRequest(requesterId);
    await persist(jr, requesterId);

    const afterRequest = await repo.findById(jr.id);
    expect(afterRequest?.status).toBe('pending');
    afterRequest?.approve({ by: hostUserId, now: new Date(), eventSnapshot: eventSnapshot() });
    if (afterRequest) await persist(afterRequest, hostUserId);

    const afterApprove = await repo.findById(jr.id);
    expect(afterApprove?.status).toBe('approved');

    const removalTime = new Date();
    const removalReason = 'Violated community guidelines';
    afterApprove?.removeByHost({
      by: hostUserId,
      reason: removalReason,
      now: removalTime,
      hostUserId,
    });
    if (afterApprove) await persist(afterApprove, hostUserId);

    const reloaded = await repo.findById(jr.id);
    expect(reloaded).not.toBeNull();
    if (!reloaded) return;
    expect(reloaded.status).toBe('removed_by_host');
    expect(reloaded.decidedAt?.getTime()).toBe(removalTime.getTime());
    expect(reloaded.decidedByUserId).toBe(hostUserId);
    expect(reloaded.decisionReason).toBe(removalReason);
  });
});
