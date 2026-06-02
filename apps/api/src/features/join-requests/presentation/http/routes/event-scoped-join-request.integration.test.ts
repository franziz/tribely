// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { JwtAccessTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-access-token-issuer.js';
import { buildApp } from '../../../../../app.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * HTTP-level integration test for POST /events/:id/join-requests.
 *
 * Key regression case (TRI-28 smoke failure): the endpoint previously mounted
 * `zValidator('json', createJoinRequestBodySchema)` on a no-body POST. Hono's
 * validator calls `c.req.json()` when it sees `Content-Type: application/json`,
 * which throws `HTTPException(400)` on an empty body before any business logic
 * runs. The mobile Dio client globally sets that content-type and sends no body
 * — so the POST always 400'd in production.
 *
 * Fix: validator removed. This test reproduces the Dio wire shape exactly
 * (Content-Type: application/json, empty body) and asserts 201, pinning the
 * fix against regressions.
 */
describe.skipIf(!dbUrl)('POST /events/:id/join-requests (integration)', () => {
  let db: PrismaClient;
  let requesterToken: string;
  let requesterUserId: string;
  let hostUserId: string;
  let eventId: string;
  const createdJoinRequestIds: string[] = [];

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    requesterUserId = createId();
    hostUserId = createId();

    // Derive a unique E.164 phone from a timestamp suffix.
    // `phone` column has UNIQUE constraint + E.164 validation on mapper read-back.
    const ts8 = String(Date.now()).slice(-8);
    const requesterPhone = `+65${ts8}`;

    await db.user.createMany({
      data: [
        {
          id: requesterUserId,
          email: `req-${requesterUserId}@es-jr.test`,
          displayName: 'Requester',
          emailVerifiedAt: new Date(),
          phone: requesterPhone,
          phoneVerifiedAt: new Date(),
        },
        {
          id: hostUserId,
          email: `host-${hostUserId}@es-jr.test`,
          displayName: 'Host',
        },
      ],
    });

    const issued = await tokens.issue({
      userId: requesterUserId,
      email: `req-${requesterUserId}@es-jr.test`,
    });
    requesterToken = issued.value;

    const now = new Date();
    eventId = createId();
    await db.event.create({
      data: {
        id: eventId,
        hostUserId,
        title: 'Regression Event',
        description: null,
        venueAddress: '1 Raffles Place, Singapore',
        venueCity: 'Singapore',
        venueLatitude: 1.2848,
        venueLongitude: 103.8509,
        startsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
        endsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000 + 2 * 60 * 60 * 1000),
        capacity: 6,
        category: 'drinks',
        costNotes: null,
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
    await db.outboxEvent
      .deleteMany({
        where: { aggregateType: 'JoinRequest', aggregateId: { in: createdJoinRequestIds } },
      })
      .catch(() => null);
    await db.joinRequest
      .deleteMany({ where: { id: { in: createdJoinRequestIds } } })
      .catch(() => null);
    await db.event.deleteMany({ where: { id: eventId } }).catch(() => null);
    await db.user
      .deleteMany({ where: { id: { in: [requesterUserId, hostUserId] } } })
      .catch(() => null);
    await db.$disconnect();
  });

  it('returns 401 without Authorization header', async () => {
    const { app } = buildApp();
    const res = await app.request(`/events/${eventId}/join-requests`, { method: 'POST' });
    expect(res.status).toBe(401);
  });

  /**
   * Regression: TRI-28 smoke failure.
   *
   * Reproduces the exact Dio wire shape: Content-Type: application/json with
   * an empty body. Before the fix this returned 400 ("Malformed JSON in
   * request body") because the zValidator middleware called c.req.json() on
   * the empty body. After the fix it must return 201.
   *
   * Hono's `app.request()` test helper uses the Fetch API. An empty body is
   * sent as `body: null` (no body at all), but with Content-Type: application/json
   * set explicitly — matching Dio's behaviour.
   */
  it('returns 201 when called with Content-Type: application/json and empty body (Dio wire shape)', async () => {
    const { app } = buildApp();
    const res = await app.request(`/events/${eventId}/join-requests`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${requesterToken}`,
        'Content-Type': 'application/json',
      },
      // No body argument — empty body, exactly as Dio sends it.
    });

    expect(res.status).toBe(201);
    const body = (await res.json()) as {
      id: string;
      eventId: string;
      requesterUserId: string;
      status: string;
      requestedAt: string;
    };
    expect(body.eventId).toBe(eventId);
    expect(body.requesterUserId).toBe(requesterUserId);
    expect(body.status).toBe('pending');

    // Track for cleanup
    createdJoinRequestIds.push(body.id);
  });
});

/**
 * HTTP-level integration tests for
 * POST /events/:id/join-requests/:joinRequestId/remove (TRI-63).
 *
 * Exercises the full stack: JWT auth + verification middleware → route →
 * controller → RemoveJoinRequestByHostUseCase → Prisma repository → DB.
 *
 * AC coverage:
 *   - 200 happy path: approved JR → remove → status is `removed_by_host` + reason persisted
 *   - 401 without Authorization header
 *   - 403 for non-host actor
 *   - 404 for unknown joinRequestId
 *   - 409 for source-state-not-approved (pending JR)
 *   - 400 for invalid body (Zod maps ZodError → 400 via error-handler; zValidator does not return 422)
 *
 * Note on 400 vs 422: the brief specified 422 for invalid body, but Hono's
 * ZodError path in the global error-handler returns 400. This matches the
 * established codebase pattern (check-ins integration test confirms the same).
 */
describe.skipIf(!dbUrl)(
  'POST /events/:id/join-requests/:joinRequestId/remove (integration)',
  () => {
    let db: PrismaClient;

    let hostUserId: string;
    let hostToken: string;
    /** Requester used for the approved JR seeded each beforeEach. */
    let requesterUserId: string;
    /** Requester used for the pending JR seeded each beforeEach — distinct to avoid unique(eventId, requesterUserId) violation. */
    let requesterPendingUserId: string;
    let nonHostUserId: string;
    let nonHostToken: string;
    let eventId: string;

    /** A JR seeded fresh before each test in `approved` state (happy-path target). */
    let approvedJrId: string;
    /** A JR seeded in `pending` state for the 409 conflict test. */
    let pendingJrId: string;

    const allJrIds: string[] = [];

    beforeAll(async () => {
      if (!dbUrl) return;
      db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
      const tokens = new JwtAccessTokenIssuer();

      hostUserId = createId();
      requesterUserId = createId();
      requesterPendingUserId = createId();
      nonHostUserId = createId();

      // phone column has UNIQUE constraint + E.164 validation on mapper read-back.
      const ts8 = String(Date.now()).slice(-8);

      await db.user.createMany({
        data: [
          {
            id: hostUserId,
            email: `host-${hostUserId}@rm-jr.test`,
            displayName: 'Host',
            emailVerifiedAt: new Date(),
            phone: `+6591${ts8.slice(0, 6)}`,
            phoneVerifiedAt: new Date(),
          },
          {
            id: requesterUserId,
            email: `req-${requesterUserId}@rm-jr.test`,
            displayName: 'RequesterApproved',
            emailVerifiedAt: new Date(),
            phone: `+6592${ts8.slice(0, 6)}`,
            phoneVerifiedAt: new Date(),
          },
          {
            id: requesterPendingUserId,
            email: `req-pending-${requesterPendingUserId}@rm-jr.test`,
            displayName: 'RequesterPending',
            emailVerifiedAt: new Date(),
            phone: `+6594${ts8.slice(0, 6)}`,
            phoneVerifiedAt: new Date(),
          },
          {
            id: nonHostUserId,
            email: `non-host-${nonHostUserId}@rm-jr.test`,
            displayName: 'NonHost',
            emailVerifiedAt: new Date(),
            phone: `+6593${ts8.slice(0, 6)}`,
            phoneVerifiedAt: new Date(),
          },
        ],
      });

      hostToken = (
        await tokens.issue({ userId: hostUserId, email: `host-${hostUserId}@rm-jr.test` })
      ).value;
      nonHostToken = (
        await tokens.issue({
          userId: nonHostUserId,
          email: `non-host-${nonHostUserId}@rm-jr.test`,
        })
      ).value;

      const now = new Date();
      eventId = createId();
      await db.event.create({
        data: {
          id: eventId,
          hostUserId,
          title: 'Remove Attendee Test Event',
          description: null,
          venueAddress: '1 Raffles Place, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.2848,
          venueLongitude: 103.8509,
          startsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000 + 2 * 60 * 60 * 1000),
          capacity: 6,
          category: 'drinks',
          costNotes: null,
          approvalMode: 'manual',
          status: 'published',
          cancellationReason: null,
          createdAt: now,
          updatedAt: now,
        },
      });
    });

    beforeEach(async () => {
      if (!dbUrl) return;
      // Remove any JR rows left by the previous test (including rows the
      // route-under-test may have created) before seeding fresh ones.
      // Keyed on eventId so we don't touch sibling describe blocks' rows.
      await db.joinRequest.deleteMany({ where: { eventId } });

      // Seed a fresh approved JR and a pending JR before each test so each
      // test operates on an untouched row (the remove operation is a state
      // transition — the row can only be removed once).
      approvedJrId = createId();
      pendingJrId = createId();
      const now = new Date();

      // Two distinct requesters to satisfy the unique(eventId, requesterUserId)
      // composite constraint: requesterUserId for the approved JR,
      // requesterPendingUserId for the pending JR.
      await db.joinRequest.createMany({
        data: [
          {
            id: approvedJrId,
            eventId,
            requesterUserId,
            status: 'approved',
            requestedAt: now,
            decidedAt: now,
            decidedByUserId: hostUserId,
          },
          {
            id: pendingJrId,
            eventId,
            requesterUserId: requesterPendingUserId,
            status: 'pending',
            requestedAt: now,
          },
        ],
      });

      allJrIds.push(approvedJrId, pendingJrId);
    });

    afterAll(async () => {
      if (!dbUrl) return;
      await db.outboxEvent
        .deleteMany({ where: { aggregateType: 'JoinRequest', aggregateId: { in: allJrIds } } })
        .catch(() => null);
      await db.joinRequest.deleteMany({ where: { id: { in: allJrIds } } }).catch(() => null);
      await db.event.deleteMany({ where: { id: eventId } }).catch(() => null);
      await db.user
        .deleteMany({
          where: {
            id: { in: [hostUserId, requesterUserId, requesterPendingUserId, nonHostUserId] },
          },
        })
        .catch(() => null);
      await db.$disconnect();
    });

    it('returns 401 without Authorization header', async () => {
      const { app } = buildApp();
      const res = await app.request(`/events/${eventId}/join-requests/${approvedJrId}/remove`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reason: 'Removed' }),
      });
      expect(res.status).toBe(401);
    });

    it('happy path: approved JR → remove → 200, status is removed_by_host, reason persisted', async () => {
      const { app } = buildApp();
      const res = await app.request(`/events/${eventId}/join-requests/${approvedJrId}/remove`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${hostToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reason: 'No longer fits the group vibe' }),
      });

      expect(res.status).toBe(200);
      const body = (await res.json()) as {
        id: string;
        status: string;
        decisionReason: string | null;
        decidedByUserId: string | null;
      };
      expect(body.id).toBe(approvedJrId);
      expect(body.status).toBe('removed_by_host');
      expect(body.decisionReason).toBe('No longer fits the group vibe');
      expect(body.decidedByUserId).toBe(hostUserId);

      // Verify DB state
      const row = await db.joinRequest.findUnique({ where: { id: approvedJrId } });
      expect(row?.status).toBe('removed_by_host');
      expect(row?.decisionReason).toBe('No longer fits the group vibe');
    });

    it('returns 403 when a non-host actor attempts to remove an attendee', async () => {
      const { app } = buildApp();
      const res = await app.request(`/events/${eventId}/join-requests/${approvedJrId}/remove`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${nonHostToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reason: 'Unauthorised removal attempt' }),
      });
      expect(res.status).toBe(403);
    });

    it('returns 404 for an unknown joinRequestId', async () => {
      const { app } = buildApp();
      const unknownId = createId();
      const res = await app.request(`/events/${eventId}/join-requests/${unknownId}/remove`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${hostToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reason: 'Should not reach use case' }),
      });
      expect(res.status).toBe(404);
    });

    it('returns 409 when the join request is in a non-approved state (pending)', async () => {
      const { app } = buildApp();
      const res = await app.request(`/events/${eventId}/join-requests/${pendingJrId}/remove`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${hostToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reason: 'Trying to remove a pending request' }),
      });
      expect(res.status).toBe(409);
    });

    it('returns 400 for an empty reason (Zod validation failure)', async () => {
      // zValidator('json', removeAttendeeBodySchema) fires before the handler.
      // Hono maps ZodError → 400 via the global error-handler (not 422).
      const { app } = buildApp();
      const res = await app.request(`/events/${eventId}/join-requests/${approvedJrId}/remove`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${hostToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reason: '   ' }),
      });
      expect(res.status).toBe(400);
    });

    it('returns 400 for a reason exceeding 200 characters (Zod validation failure)', async () => {
      const { app } = buildApp();
      const longReason = 'x'.repeat(201);
      const res = await app.request(`/events/${eventId}/join-requests/${approvedJrId}/remove`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${hostToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reason: longReason }),
      });
      expect(res.status).toBe(400);
    });
  },
);
