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
