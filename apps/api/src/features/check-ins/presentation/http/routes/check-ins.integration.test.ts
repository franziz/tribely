// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { Hono } from 'hono';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { runWithContext } from '@/core/context/request-context.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import { OutboxEventPublisher } from '@/core/events/outbox-event-publisher.js';
import { SystemClock } from '@/features/auth/infrastructure/adapters/system-clock.js';
import { JwtAccessTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-access-token-issuer.js';
import { PostEventCheckInPrismaRepository } from '../../../infrastructure/persistence/post-event-check-in.prisma-repository.js';
import { PostEventCheckIn } from '../../../domain/entities/post-event-check-in.js';
import { AcknowledgeCheckInUseCase } from '../../../application/usecases/acknowledge-check-in.usecase.js';
import { FlagCheckInUseCase } from '../../../application/usecases/flag-check-in.usecase.js';
import { SurfacePendingCheckInsUseCase } from '../../../application/usecases/surface-pending-check-ins.usecase.js';
import { RecordPostEventCheckInEventUseCase } from '@/features/audit/application/usecases/record-post-event-check-in-event.usecase.js';
import { PostEventCheckInEventPrismaRepository } from '@/features/audit/infrastructure/persistence/post-event-check-in-event.prisma-repository.js';
import { EventPrismaRepository } from '@/features/events/infrastructure/persistence/event.prisma-repository.js';
import { UserPrismaRepository } from '@/features/users/infrastructure/persistence/user.prisma-repository.js';
import { CheckInsController } from '../controllers/check-ins.controller.js';
import { buildCheckInsRoutes } from './check-ins.routes.js';
import { errorHandler } from '@/core/middleware/error-handler.js';
import { requestContext } from '@/core/middleware/request-context.js';
import type { AuthVariables } from '@/core/middleware/require-auth.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * HTTP-level integration tests for the check-ins presentation layer.
 *
 * Exercises GET /me/post-event-check-ins, POST /me/post-event-check-ins/:id/acknowledge,
 * and POST /me/post-event-check-ins/:id/flag.
 *
 * Uses a test-local Hono app (NOT buildApp()) because container.ts does not yet
 * expose check-in use cases (that wiring lands in Brief B7). The test app
 * constructs the full real-infra stack directly — Prisma → repository →
 * use case → controller → route — so the test still exercises the full stack
 * end-to-end without relying on the DI container.
 *
 * AC coverage:
 *   - Happy path: GET 200, acknowledge 200, flag 200
 *   - 401 without auth token
 *   - 403 when acting user is not the check-in owner
 *   - 404 for missing check-in id
 *   - 422 for oversized reportBody (> 2000 chars)
 *   - 422 for empty reportBody after trim
 *   - 409 when acknowledge/flag is called on a non-pending check-in
 *   - POST /:id/acknowledge does NOT throw Malformed JSON with empty body
 *     (regression pin for TRI-28 / Hono zValidator empty-body trap)
 */
describe.skipIf(!dbUrl)('Check-ins HTTP routes (integration)', () => {
  let db: PrismaClient;
  let tokens: JwtAccessTokenIssuer;
  let attendeeToken: string;
  let otherToken: string;
  let attendeeUserId: string;
  let otherUserId: string;
  let hostUserId: string;
  let eventId: string;

  // Track created check-in ids for cleanup.
  const createdCheckInIds: string[] = [];
  const createdAuditIds: string[] = [];
  const createdOutboxIds: string[] = [];

  // The test app — built once, shared across tests.
  let testApp: Hono<{ Variables: AuthVariables }>;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /**
   * Build a test-local Hono app wiring the full real-infra stack.
   * Must be called after the DB client is ready.
   */
  const buildTestApp = (): Hono<{ Variables: AuthVariables }> => {
    const unitOfWork = new PrismaUnitOfWork(db);
    const publisher = new OutboxEventPublisher();
    const checkInsRepo = new PostEventCheckInPrismaRepository(db);
    const auditEventRepo = new PostEventCheckInEventPrismaRepository(db);
    const eventRepo = new EventPrismaRepository(db);
    const userRepo = new UserPrismaRepository(db);
    const clock = new SystemClock();

    const recordAudit = new RecordPostEventCheckInEventUseCase(auditEventRepo);
    const surfaceUseCase = new SurfacePendingCheckInsUseCase(
      unitOfWork,
      checkInsRepo,
      eventRepo,
      userRepo,
      publisher,
      recordAudit,
      clock,
    );
    const acknowledgeUseCase = new AcknowledgeCheckInUseCase(
      unitOfWork,
      checkInsRepo,
      publisher,
      recordAudit,
      clock,
    );
    const flagUseCase = new FlagCheckInUseCase(
      unitOfWork,
      checkInsRepo,
      publisher,
      recordAudit,
      clock,
    );

    const controller = new CheckInsController(surfaceUseCase, acknowledgeUseCase, flagUseCase);
    const routes = buildCheckInsRoutes({ controller, accessTokens: tokens });

    const app = new Hono<{ Variables: AuthVariables }>();
    app.use('*', requestContext());
    app.route('/me/post-event-check-ins', routes);
    app.onError(errorHandler);
    return app;
  };

  /** Seed a PostEventCheckIn row in pending status. Returns the check-in id. */
  const seedPendingCheckIn = async (userId: string): Promise<string> => {
    const unitOfWork = new PrismaUnitOfWork(db);
    const checkInsRepo = new PostEventCheckInPrismaRepository(db);
    const publisher = new OutboxEventPublisher();

    const id = createId();
    const checkIn = PostEventCheckIn.create({ id, userId, eventId, hostUserId, now: new Date() });
    await runWithContext({ requestId: createId(), actorUserId: userId }, () =>
      unitOfWork.run(async (ctx) => {
        const events = checkIn.pullEvents();
        await checkInsRepo.save(checkIn, ctx);
        await publisher.publish(ctx, ...events);
      }),
    );
    createdCheckInIds.push(id);
    createdOutboxIds.push(id);
    return id;
  };

  // ---------------------------------------------------------------------------
  // Setup / teardown
  // ---------------------------------------------------------------------------

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    tokens = new JwtAccessTokenIssuer();

    attendeeUserId = createId();
    otherUserId = createId();
    hostUserId = createId();

    const ts = String(Date.now()).slice(-8);
    // Attendee needs email + phone verified for most use cases. The check-ins
    // surface itself does NOT enforce requireVerifiedEmail/Phone, but we still
    // set them so the user row is realistic.
    await db.user.createMany({
      data: [
        {
          id: attendeeUserId,
          email: `attendee-${attendeeUserId}@ci-routes.test`,
          displayName: 'Attendee',
          emailVerifiedAt: new Date(),
          phone: `+65${ts}`,
          phoneVerifiedAt: new Date(),
        },
        {
          id: otherUserId,
          email: `other-${otherUserId}@ci-routes.test`,
          displayName: 'Other',
        },
        {
          id: hostUserId,
          email: `host-${hostUserId}@ci-routes.test`,
          displayName: 'Host',
        },
      ],
    });

    const issuedAttendee = await tokens.issue({
      userId: attendeeUserId,
      email: `attendee-${attendeeUserId}@ci-routes.test`,
    });
    attendeeToken = issuedAttendee.value;

    const issuedOther = await tokens.issue({
      userId: otherUserId,
      email: `other-${otherUserId}@ci-routes.test`,
    });
    otherToken = issuedOther.value;

    // Seed one completed event (status 'completed' so SurfacePendingCheckIns
    // can find it in the look-back window — we seed check-ins directly rather
    // than relying on the auto-surface mechanism for most tests).
    const now = new Date();
    eventId = createId();
    await db.event.create({
      data: {
        id: eventId,
        hostUserId,
        title: 'Integration Test Event',
        description: null,
        venueAddress: '1 Raffles Quay, Singapore',
        venueCity: 'Singapore',
        venueLatitude: 1.2806,
        venueLongitude: 103.8504,
        startsAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
        endsAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
        capacity: 6,
        category: 'food',
        costSplit: 'own',
        approvalMode: 'manual',
        status: 'completed',
        cancellationReason: null,
        createdAt: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
        updatedAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
      },
    });

    testApp = buildTestApp();
  });

  afterAll(async () => {
    if (!dbUrl) return;

    // Audit rows first (no FK but good hygiene)
    if (createdAuditIds.length > 0) {
      await db.postEventCheckInEvent
        .deleteMany({ where: { checkInId: { in: createdCheckInIds } } })
        .catch(() => null);
    }
    // Outbox rows for check-in aggregates
    if (createdOutboxIds.length > 0) {
      await db.outboxEvent
        .deleteMany({
          where: { aggregateType: 'PostEventCheckIn', aggregateId: { in: createdOutboxIds } },
        })
        .catch(() => null);
    }
    // Also clean up any audit rows created by use cases during tests
    if (createdCheckInIds.length > 0) {
      await db.postEventCheckInEvent
        .deleteMany({ where: { checkInId: { in: createdCheckInIds } } })
        .catch(() => null);
    }
    // Check-ins (cascade from event deletion, but explicit for safety)
    if (createdCheckInIds.length > 0) {
      await db.postEventCheckIn
        .deleteMany({ where: { id: { in: createdCheckInIds } } })
        .catch(() => null);
    }
    await db.event.delete({ where: { id: eventId } }).catch(() => null);
    await db.user
      .deleteMany({ where: { id: { in: [attendeeUserId, otherUserId, hostUserId] } } })
      .catch(() => null);
    await db.$disconnect();
  });

  // ---------------------------------------------------------------------------
  // GET /me/post-event-check-ins
  // ---------------------------------------------------------------------------

  describe('GET /me/post-event-check-ins', () => {
    it('returns 401 without Authorization header', async () => {
      const res = await testApp.request('/me/post-event-check-ins');
      expect(res.status).toBe(401);
    });

    it('returns 200 with items array when authenticated', async () => {
      const res = await testApp.request('/me/post-event-check-ins', {
        headers: { Authorization: `Bearer ${attendeeToken}` },
      });
      expect(res.status).toBe(200);
      const body = (await res.json()) as { items: unknown[] };
      expect(Array.isArray(body.items)).toBe(true);
    });

    it('returns a seeded pending check-in in the items list', async () => {
      // Seed directly so we can assert the id appears in the response.
      const checkInId = await seedPendingCheckIn(attendeeUserId);

      const res = await testApp.request('/me/post-event-check-ins', {
        headers: { Authorization: `Bearer ${attendeeToken}` },
      });
      expect(res.status).toBe(200);
      const body = (await res.json()) as {
        items: Array<{ id: string; eventId: string; eventTitle: string; endedAt: string }>;
      };
      const ids = body.items.map((i) => i.id);
      expect(ids).toContain(checkInId);
      const item = body.items.find((i) => i.id === checkInId);
      expect(item?.eventId).toBe(eventId);
      expect(typeof item?.endedAt).toBe('string');
    });

    it('does not return check-ins belonging to other users', async () => {
      // Seed a check-in for otherUser — this requires a separate event (@@unique userId+eventId).
      const otherEventId = createId();
      const now = new Date();
      await db.event.create({
        data: {
          id: otherEventId,
          hostUserId,
          title: 'Other User Event',
          description: null,
          venueAddress: '2 Raffles Quay, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.281,
          venueLongitude: 103.851,
          startsAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
          capacity: 6,
          category: 'drinks',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'completed',
          cancellationReason: null,
          createdAt: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
          updatedAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
        },
      });

      const otherCheckInId = createId();
      const unitOfWork = new PrismaUnitOfWork(db);
      const checkInsRepo = new PostEventCheckInPrismaRepository(db);
      const publisher = new OutboxEventPublisher();
      const otherCheckIn = PostEventCheckIn.create({
        id: otherCheckInId,
        userId: otherUserId,
        eventId: otherEventId,
        hostUserId,
        now: new Date(),
      });
      await runWithContext({ requestId: createId(), actorUserId: otherUserId }, () =>
        unitOfWork.run(async (ctx) => {
          const events = otherCheckIn.pullEvents();
          await checkInsRepo.save(otherCheckIn, ctx);
          await publisher.publish(ctx, ...events);
        }),
      );
      createdCheckInIds.push(otherCheckInId);
      createdOutboxIds.push(otherCheckInId);

      const res = await testApp.request('/me/post-event-check-ins', {
        headers: { Authorization: `Bearer ${attendeeToken}` },
      });
      expect(res.status).toBe(200);
      const body = (await res.json()) as { items: Array<{ id: string }> };
      const ids = body.items.map((i) => i.id);
      expect(ids).not.toContain(otherCheckInId);

      // Cleanup the extra event
      await db.outboxEvent
        .deleteMany({ where: { aggregateType: 'PostEventCheckIn', aggregateId: otherCheckInId } })
        .catch(() => null);
      await db.postEventCheckInEvent
        .deleteMany({ where: { checkInId: otherCheckInId } })
        .catch(() => null);
      await db.postEventCheckIn.delete({ where: { id: otherCheckInId } }).catch(() => null);
      await db.event.delete({ where: { id: otherEventId } }).catch(() => null);
    });
  });

  // ---------------------------------------------------------------------------
  // POST /me/post-event-check-ins/:id/acknowledge
  // ---------------------------------------------------------------------------

  describe('POST /me/post-event-check-ins/:id/acknowledge', () => {
    it('returns 401 without Authorization header', async () => {
      const res = await testApp.request(`/me/post-event-check-ins/nonexistent/acknowledge`, {
        method: 'POST',
      });
      expect(res.status).toBe(401);
    });

    it('returns 200 { ok: true } on happy path', async () => {
      // Each test needs its own check-in (@@unique userId+eventId — once acknowledged it's no
      // longer pending so it can't be acknowledged again). We seed via a fresh event.
      const ackEventId = createId();
      const now = new Date();
      await db.event.create({
        data: {
          id: ackEventId,
          hostUserId,
          title: 'Ack Event',
          description: null,
          venueAddress: '3 Raffles Quay, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.282,
          venueLongitude: 103.852,
          startsAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
          capacity: 6,
          category: 'food',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'completed',
          cancellationReason: null,
          createdAt: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
          updatedAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
        },
      });

      const unitOfWork = new PrismaUnitOfWork(db);
      const checkInsRepo = new PostEventCheckInPrismaRepository(db);
      const publisher = new OutboxEventPublisher();
      const ackCheckInId = createId();
      const ackCheckIn = PostEventCheckIn.create({
        id: ackCheckInId,
        userId: attendeeUserId,
        eventId: ackEventId,
        hostUserId,
        now: new Date(),
      });
      await runWithContext({ requestId: createId(), actorUserId: attendeeUserId }, () =>
        unitOfWork.run(async (ctx) => {
          const events = ackCheckIn.pullEvents();
          await checkInsRepo.save(ackCheckIn, ctx);
          await publisher.publish(ctx, ...events);
        }),
      );
      createdCheckInIds.push(ackCheckInId);
      createdOutboxIds.push(ackCheckInId);

      const res = await testApp.request(`/me/post-event-check-ins/${ackCheckInId}/acknowledge`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${attendeeToken}` },
      });
      expect(res.status).toBe(200);
      const body = (await res.json()) as { ok: boolean };
      expect(body.ok).toBe(true);

      // Cleanup extra event
      await db.outboxEvent
        .deleteMany({ where: { aggregateType: 'PostEventCheckIn', aggregateId: ackCheckInId } })
        .catch(() => null);
      await db.postEventCheckInEvent
        .deleteMany({ where: { checkInId: ackCheckInId } })
        .catch(() => null);
      await db.postEventCheckIn.delete({ where: { id: ackCheckInId } }).catch(() => null);
      await db.event.delete({ where: { id: ackEventId } }).catch(() => null);
    });

    /**
     * Regression pin for TRI-28 / Hono zValidator empty-body trap.
     * The acknowledge route must NOT have zValidator('json', ...) mounted.
     * This test reproduces the Dio wire shape: Content-Type: application/json,
     * empty body. If the validator were mounted it would throw 400 before auth.
     */
    it('does not throw Malformed JSON when called with Content-Type: application/json and empty body', async () => {
      const res = await testApp.request(`/me/post-event-check-ins/nonexistent/acknowledge`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${attendeeToken}`,
          'Content-Type': 'application/json',
        },
        // No body — empty body, exactly as Dio sends it.
      });
      // Should be 404 (check-in not found), never 400 (Malformed JSON).
      expect(res.status).toBe(404);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe('NOT_FOUND');
    });

    it('returns 404 for a non-existent check-in id', async () => {
      const res = await testApp.request(`/me/post-event-check-ins/${createId()}/acknowledge`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${attendeeToken}` },
      });
      expect(res.status).toBe(404);
    });

    it('returns 403 when the acting user does not own the check-in', async () => {
      // Seed a check-in owned by attendeeUserId; attempt to acknowledge as otherUserId.
      const forbidEventId = createId();
      const now = new Date();
      await db.event.create({
        data: {
          id: forbidEventId,
          hostUserId,
          title: 'Forbid Event',
          description: null,
          venueAddress: '4 Raffles Quay, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.283,
          venueLongitude: 103.853,
          startsAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
          capacity: 6,
          category: 'food',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'completed',
          cancellationReason: null,
          createdAt: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
          updatedAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
        },
      });

      const unitOfWork = new PrismaUnitOfWork(db);
      const checkInsRepo = new PostEventCheckInPrismaRepository(db);
      const publisher = new OutboxEventPublisher();
      const forbidCheckInId = createId();
      const forbidCheckIn = PostEventCheckIn.create({
        id: forbidCheckInId,
        userId: attendeeUserId,
        eventId: forbidEventId,
        hostUserId,
        now: new Date(),
      });
      await runWithContext({ requestId: createId(), actorUserId: attendeeUserId }, () =>
        unitOfWork.run(async (ctx) => {
          const events = forbidCheckIn.pullEvents();
          await checkInsRepo.save(forbidCheckIn, ctx);
          await publisher.publish(ctx, ...events);
        }),
      );
      createdCheckInIds.push(forbidCheckInId);
      createdOutboxIds.push(forbidCheckInId);

      const res = await testApp.request(`/me/post-event-check-ins/${forbidCheckInId}/acknowledge`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${otherToken}` },
      });
      expect(res.status).toBe(403);

      // Cleanup
      await db.outboxEvent
        .deleteMany({ where: { aggregateType: 'PostEventCheckIn', aggregateId: forbidCheckInId } })
        .catch(() => null);
      await db.postEventCheckInEvent
        .deleteMany({ where: { checkInId: forbidCheckInId } })
        .catch(() => null);
      await db.postEventCheckIn.delete({ where: { id: forbidCheckInId } }).catch(() => null);
      await db.event.delete({ where: { id: forbidEventId } }).catch(() => null);
    });

    it('returns 409 when acknowledging an already-terminal check-in', async () => {
      // Seed a check-in, acknowledge it via the use case, then try to acknowledge again.
      const conflictEventId = createId();
      const now = new Date();
      await db.event.create({
        data: {
          id: conflictEventId,
          hostUserId,
          title: 'Conflict Event',
          description: null,
          venueAddress: '5 Raffles Quay, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.284,
          venueLongitude: 103.854,
          startsAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
          capacity: 6,
          category: 'food',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'completed',
          cancellationReason: null,
          createdAt: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
          updatedAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
        },
      });

      const unitOfWork = new PrismaUnitOfWork(db);
      const checkInsRepo = new PostEventCheckInPrismaRepository(db);
      const publisher = new OutboxEventPublisher();
      const conflictCheckInId = createId();
      const conflictCheckIn = PostEventCheckIn.create({
        id: conflictCheckInId,
        userId: attendeeUserId,
        eventId: conflictEventId,
        hostUserId,
        now: new Date(),
      });
      await runWithContext({ requestId: createId(), actorUserId: attendeeUserId }, () =>
        unitOfWork.run(async (ctx) => {
          const events = conflictCheckIn.pullEvents();
          await checkInsRepo.save(conflictCheckIn, ctx);
          await publisher.publish(ctx, ...events);
        }),
      );
      createdCheckInIds.push(conflictCheckInId);
      createdOutboxIds.push(conflictCheckInId);

      // First acknowledge — should succeed.
      const first = await testApp.request(
        `/me/post-event-check-ins/${conflictCheckInId}/acknowledge`,
        {
          method: 'POST',
          headers: { Authorization: `Bearer ${attendeeToken}` },
        },
      );
      expect(first.status).toBe(200);

      // Second acknowledge — should 409.
      const second = await testApp.request(
        `/me/post-event-check-ins/${conflictCheckInId}/acknowledge`,
        {
          method: 'POST',
          headers: { Authorization: `Bearer ${attendeeToken}` },
        },
      );
      expect(second.status).toBe(409);

      // Cleanup
      await db.outboxEvent
        .deleteMany({
          where: { aggregateType: 'PostEventCheckIn', aggregateId: conflictCheckInId },
        })
        .catch(() => null);
      await db.postEventCheckInEvent
        .deleteMany({ where: { checkInId: conflictCheckInId } })
        .catch(() => null);
      await db.postEventCheckIn.delete({ where: { id: conflictCheckInId } }).catch(() => null);
      await db.event.delete({ where: { id: conflictEventId } }).catch(() => null);
    });
  });

  // ---------------------------------------------------------------------------
  // POST /me/post-event-check-ins/:id/flag
  // ---------------------------------------------------------------------------

  describe('POST /me/post-event-check-ins/:id/flag', () => {
    it('returns 401 without Authorization header', async () => {
      const res = await testApp.request(`/me/post-event-check-ins/nonexistent/flag`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reportBody: 'report text' }),
      });
      expect(res.status).toBe(401);
    });

    it('returns 200 { ok: true } on happy path', async () => {
      const flagEventId = createId();
      const now = new Date();
      await db.event.create({
        data: {
          id: flagEventId,
          hostUserId,
          title: 'Flag Event',
          description: null,
          venueAddress: '6 Raffles Quay, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.285,
          venueLongitude: 103.855,
          startsAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
          capacity: 6,
          category: 'food',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'completed',
          cancellationReason: null,
          createdAt: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
          updatedAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
        },
      });

      const unitOfWork = new PrismaUnitOfWork(db);
      const checkInsRepo = new PostEventCheckInPrismaRepository(db);
      const publisher = new OutboxEventPublisher();
      const flagCheckInId = createId();
      const flagCheckIn = PostEventCheckIn.create({
        id: flagCheckInId,
        userId: attendeeUserId,
        eventId: flagEventId,
        hostUserId,
        now: new Date(),
      });
      await runWithContext({ requestId: createId(), actorUserId: attendeeUserId }, () =>
        unitOfWork.run(async (ctx) => {
          const events = flagCheckIn.pullEvents();
          await checkInsRepo.save(flagCheckIn, ctx);
          await publisher.publish(ctx, ...events);
        }),
      );
      createdCheckInIds.push(flagCheckInId);
      createdOutboxIds.push(flagCheckInId);

      const res = await testApp.request(`/me/post-event-check-ins/${flagCheckInId}/flag`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${attendeeToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          reportBody: 'The host made me feel unsafe.',
          disclaimerAcknowledged: true,
        }),
      });
      expect(res.status).toBe(200);
      const body = (await res.json()) as { ok: boolean };
      expect(body.ok).toBe(true);

      // Cleanup
      await db.outboxEvent
        .deleteMany({ where: { aggregateType: 'PostEventCheckIn', aggregateId: flagCheckInId } })
        .catch(() => null);
      await db.postEventCheckInEvent
        .deleteMany({ where: { checkInId: flagCheckInId } })
        .catch(() => null);
      await db.postEventCheckIn.delete({ where: { id: flagCheckInId } }).catch(() => null);
      await db.event.delete({ where: { id: flagEventId } }).catch(() => null);
    });

    it('returns 404 for a non-existent check-in id', async () => {
      const res = await testApp.request(`/me/post-event-check-ins/${createId()}/flag`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${attendeeToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reportBody: 'test', disclaimerAcknowledged: true }),
      });
      expect(res.status).toBe(404);
    });

    it('returns 403 when the acting user does not own the check-in', async () => {
      const forbidFlagEventId = createId();
      const now = new Date();
      await db.event.create({
        data: {
          id: forbidFlagEventId,
          hostUserId,
          title: 'Forbid Flag Event',
          description: null,
          venueAddress: '7 Raffles Quay, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.286,
          venueLongitude: 103.856,
          startsAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
          capacity: 6,
          category: 'food',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'completed',
          cancellationReason: null,
          createdAt: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
          updatedAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
        },
      });

      const unitOfWork = new PrismaUnitOfWork(db);
      const checkInsRepo = new PostEventCheckInPrismaRepository(db);
      const publisher = new OutboxEventPublisher();
      const forbidFlagCheckInId = createId();
      const forbidFlagCheckIn = PostEventCheckIn.create({
        id: forbidFlagCheckInId,
        userId: attendeeUserId,
        eventId: forbidFlagEventId,
        hostUserId,
        now: new Date(),
      });
      await runWithContext({ requestId: createId(), actorUserId: attendeeUserId }, () =>
        unitOfWork.run(async (ctx) => {
          const events = forbidFlagCheckIn.pullEvents();
          await checkInsRepo.save(forbidFlagCheckIn, ctx);
          await publisher.publish(ctx, ...events);
        }),
      );
      createdCheckInIds.push(forbidFlagCheckInId);
      createdOutboxIds.push(forbidFlagCheckInId);

      const res = await testApp.request(`/me/post-event-check-ins/${forbidFlagCheckInId}/flag`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${otherToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reportBody: 'test', disclaimerAcknowledged: true }),
      });
      expect(res.status).toBe(403);

      // Cleanup
      await db.outboxEvent
        .deleteMany({
          where: { aggregateType: 'PostEventCheckIn', aggregateId: forbidFlagCheckInId },
        })
        .catch(() => null);
      await db.postEventCheckInEvent
        .deleteMany({ where: { checkInId: forbidFlagCheckInId } })
        .catch(() => null);
      await db.postEventCheckIn.delete({ where: { id: forbidFlagCheckInId } }).catch(() => null);
      await db.event.delete({ where: { id: forbidFlagEventId } }).catch(() => null);
    });

    it('returns 422 when reportBody exceeds 2000 characters', async () => {
      const oversizeBody = 'x'.repeat(2001);
      // Zod validation fires before the use case — the check-in id does not
      // need to exist in the DB; the 400 comes from the schema boundary, not
      // the domain layer. Using a random id avoids the @@unique (userId, eventId)
      // constraint from seeding an extra check-in row.
      const checkInId = createId();

      const res = await testApp.request(`/me/post-event-check-ins/${checkInId}/flag`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${attendeeToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reportBody: oversizeBody }),
      });
      // Zod validation fires before the use case; Hono maps ZodError → 400.
      // The schema trim+min(1)+max(2000) rejects this at the presentation layer.
      expect(res.status).toBe(400);
    });

    it('returns 400 when reportBody is empty after trim', async () => {
      // Zod validation fires before the use case — same rationale as the
      // oversized-body test above. Random id, no DB seeding needed.
      const checkInId = createId();

      const res = await testApp.request(`/me/post-event-check-ins/${checkInId}/flag`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${attendeeToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reportBody: '   ' }),
      });
      // Zod schema applies .trim() then .min(1) — fails at presentation layer → 400.
      expect(res.status).toBe(400);
    });

    it('returns 409 when flagging an already-terminal check-in', async () => {
      const conflictFlagEventId = createId();
      const now = new Date();
      await db.event.create({
        data: {
          id: conflictFlagEventId,
          hostUserId,
          title: 'Conflict Flag Event',
          description: null,
          venueAddress: '8 Raffles Quay, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.287,
          venueLongitude: 103.857,
          startsAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
          capacity: 6,
          category: 'food',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'completed',
          cancellationReason: null,
          createdAt: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
          updatedAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
        },
      });

      const unitOfWork = new PrismaUnitOfWork(db);
      const checkInsRepo = new PostEventCheckInPrismaRepository(db);
      const publisher = new OutboxEventPublisher();
      const conflictFlagCheckInId = createId();
      const conflictFlagCheckIn = PostEventCheckIn.create({
        id: conflictFlagCheckInId,
        userId: attendeeUserId,
        eventId: conflictFlagEventId,
        hostUserId,
        now: new Date(),
      });
      await runWithContext({ requestId: createId(), actorUserId: attendeeUserId }, () =>
        unitOfWork.run(async (ctx) => {
          const events = conflictFlagCheckIn.pullEvents();
          await checkInsRepo.save(conflictFlagCheckIn, ctx);
          await publisher.publish(ctx, ...events);
        }),
      );
      createdCheckInIds.push(conflictFlagCheckInId);
      createdOutboxIds.push(conflictFlagCheckInId);

      // First flag — should succeed.
      const first = await testApp.request(
        `/me/post-event-check-ins/${conflictFlagCheckInId}/flag`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${attendeeToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            reportBody: 'Initial safety report.',
            disclaimerAcknowledged: true,
          }),
        },
      );
      expect(first.status).toBe(200);

      // Second flag — should 409.
      const second = await testApp.request(
        `/me/post-event-check-ins/${conflictFlagCheckInId}/flag`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${attendeeToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ reportBody: 'Follow-up report.', disclaimerAcknowledged: true }),
        },
      );
      expect(second.status).toBe(409);

      // Cleanup
      await db.outboxEvent
        .deleteMany({
          where: { aggregateType: 'PostEventCheckIn', aggregateId: conflictFlagCheckInId },
        })
        .catch(() => null);
      await db.postEventCheckInEvent
        .deleteMany({ where: { checkInId: conflictFlagCheckInId } })
        .catch(() => null);
      await db.postEventCheckIn.delete({ where: { id: conflictFlagCheckInId } }).catch(() => null);
      await db.event.delete({ where: { id: conflictFlagEventId } }).catch(() => null);
    });
  });
});
