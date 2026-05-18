// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { runWithContext } from '@/core/context/request-context.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import { OutboxEventPublisher } from '@/core/events/outbox-event-publisher.js';
import { JwtAccessTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-access-token-issuer.js';
import { JoinRequestPrismaRepository } from '@/features/join-requests/infrastructure/persistence/join-request.prisma-repository.js';

import { buildApp } from '../../../../../app.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * HTTP-level integration test for GET /me/join-requests.
 * Exercises the full stack: JWT auth middleware → route → controller → use
 * case → Prisma repository → DB. Skipped when DATABASE_URL is unset.
 *
 * Fixtures seeded: host user, requester user, one published event, two join
 * requests (one by the requester, one by another user). The suite verifies:
 *   - 200 with the requester's request + embedded event summary
 *   - Requester does not see other users' requests
 *   - ?eventId filter scopes to one event
 *   - 401 without a token
 */
describe.skipIf(!dbUrl)('GET /me/join-requests (integration)', () => {
  let db: PrismaClient;
  let requesterToken: string;
  let requesterUserId: string;
  let hostUserId: string;
  let otherUserId: string;
  let parentEventId: string;
  let secondEventId: string;
  let requesterJrId: string;
  let otherJrId: string;
  const outboxIds: string[] = [];

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const unitOfWork = new PrismaUnitOfWork(db);
    const publisher = new OutboxEventPublisher();
    const jrRepo = new JoinRequestPrismaRepository(db);
    const tokens = new JwtAccessTokenIssuer();

    // Seed users
    requesterUserId = createId();
    hostUserId = createId();
    otherUserId = createId();
    await db.user.createMany({
      data: [
        {
          id: requesterUserId,
          email: `req-${requesterUserId}@me-jr.test`,
          displayName: 'Requester',
        },
        { id: hostUserId, email: `host-${hostUserId}@me-jr.test`, displayName: 'Host' },
        { id: otherUserId, email: `other-${otherUserId}@me-jr.test`, displayName: 'Other' },
      ],
    });

    // Mark requester's email + phone verified (requireVerifiedEmail + requireVerifiedPhone gates).
    // phone column has UNIQUE constraint + E.164 validation on mapper read-back.
    const ts8 = String(Date.now()).slice(-8);
    await db.user.update({
      where: { id: requesterUserId },
      data: {
        emailVerifiedAt: new Date(),
        phone: `+65${ts8}`,
        phoneVerifiedAt: new Date(),
      },
    });

    const issued = await tokens.issue({
      userId: requesterUserId,
      email: `req-${requesterUserId}@me-jr.test`,
    });
    requesterToken = issued.value;

    // Seed events
    const now = new Date();
    parentEventId = createId();
    secondEventId = createId();
    await db.event.createMany({
      data: [
        {
          id: parentEventId,
          hostUserId,
          title: 'Parent Event',
          description: null,
          venueAddress: '1 Raffles Quay, Singapore',
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
        {
          id: secondEventId,
          hostUserId,
          title: 'Second Event',
          description: null,
          venueAddress: '2 Raffles Quay, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.281,
          venueLongitude: 103.851,
          startsAt: new Date(now.getTime() + 8 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() + 8 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
          capacity: 6,
          category: 'drinks',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'published',
          cancellationReason: null,
          createdAt: new Date(now.getTime() + 1),
          updatedAt: new Date(now.getTime() + 1),
        },
      ],
    });

    // Seed join requests via repository (uses real domain logic)
    requesterJrId = createId();
    otherJrId = createId();
    const snapshot = {
      startsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
      endsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
      venue: {
        address: '1 Raffles Quay, Singapore',
        city: 'Singapore',
        latitude: 1.2806,
        longitude: 103.8504,
      },
      hostUserId,
    };

    const { JoinRequest } =
      await import('@/features/join-requests/domain/entities/join-request.js');

    const requesterJr = JoinRequest.request({
      id: requesterJrId,
      eventId: parentEventId,
      requesterUserId,
      now: new Date(),
      autoApprove: false,
      hostUserId,
      eventSnapshot: snapshot,
    });
    const otherJr = JoinRequest.request({
      id: otherJrId,
      eventId: parentEventId,
      requesterUserId: otherUserId,
      now: new Date(now.getTime() + 100),
      autoApprove: false,
      hostUserId,
      eventSnapshot: snapshot,
    });

    await runWithContext({ requestId: createId(), actorUserId: requesterUserId }, () =>
      unitOfWork.run(async (ctx) => {
        const events = requesterJr.pullEvents();
        await jrRepo.save(requesterJr, ctx);
        await publisher.publish(ctx, ...events);
      }),
    );
    await runWithContext({ requestId: createId(), actorUserId: otherUserId }, () =>
      unitOfWork.run(async (ctx) => {
        const events = otherJr.pullEvents();
        await jrRepo.save(otherJr, ctx);
        await publisher.publish(ctx, ...events);
      }),
    );

    outboxIds.push(requesterJrId, otherJrId);
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.outboxEvent
      .deleteMany({ where: { aggregateType: 'JoinRequest', aggregateId: { in: outboxIds } } })
      .catch(() => null);
    await db.joinRequest
      .deleteMany({ where: { id: { in: [requesterJrId, otherJrId] } } })
      .catch(() => null);
    await db.event
      .deleteMany({ where: { id: { in: [parentEventId, secondEventId] } } })
      .catch(() => null);
    await db.user
      .deleteMany({ where: { id: { in: [requesterUserId, hostUserId, otherUserId] } } })
      .catch(() => null);
    await db.$disconnect();
  });

  it('returns 401 without Authorization header', async () => {
    const { app } = buildApp();
    const res = await app.request('/me/join-requests');
    expect(res.status).toBe(401);
  });

  it("returns the requester's own join requests with embedded event summary", async () => {
    const { app } = buildApp();
    const res = await app.request('/me/join-requests', {
      headers: { Authorization: `Bearer ${requesterToken}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      joinRequests: Array<{
        joinRequest: { id: string; requesterUserId: string };
        event: { id: string; title: string; venue: { city: string } };
      }>;
      nextCursor: string | null;
    };
    const ids = body.joinRequests.map((i) => i.joinRequest.id);
    expect(ids).toContain(requesterJrId);
    expect(ids).not.toContain(otherJrId);
    const item = body.joinRequests.find((i) => i.joinRequest.id === requesterJrId);
    expect(item?.event.id).toBe(parentEventId);
    expect(item?.event.title).toBe('Parent Event');
    expect(item?.event.venue.city).toBe('Singapore');
    expect(body.nextCursor).toBeNull();
  });

  it('?eventId filter scopes results to one event', async () => {
    const { app } = buildApp();
    const res = await app.request(`/me/join-requests?eventId=${parentEventId}`, {
      headers: { Authorization: `Bearer ${requesterToken}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      joinRequests: Array<{ joinRequest: { id: string } }>;
    };
    const ids = body.joinRequests.map((i) => i.joinRequest.id);
    expect(ids).toContain(requesterJrId);
  });

  it('?eventId filter with an event the requester did not join returns empty', async () => {
    const { app } = buildApp();
    const res = await app.request(`/me/join-requests?eventId=${secondEventId}`, {
      headers: { Authorization: `Bearer ${requesterToken}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { joinRequests: unknown[] };
    expect(body.joinRequests).toHaveLength(0);
  });
});
