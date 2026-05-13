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
 * HTTP-level integration test for GET /me/events.
 * Exercises the full stack: JWT auth middleware → requireVerifiedEmail →
 * route → controller → use case → Prisma repository → DB.
 * Skipped when DATABASE_URL is unset.
 *
 * Fixtures: two users (host + other), three events (two hosted by host,
 * one hosted by other). Verifies:
 *   - 401 without a token
 *   - 200 + only the host's events when authenticated
 *   - empty array when authenticated user hosts no events
 */
describe.skipIf(!dbUrl)('GET /me/events (integration)', () => {
  let db: PrismaClient;
  let hostToken: string;
  let hostUserId: string;
  let otherUserId: string;
  let hostEventId1: string;
  let hostEventId2: string;
  let otherEventId: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    // Seed users
    hostUserId = createId();
    otherUserId = createId();
    await db.user.createMany({
      data: [
        {
          id: hostUserId,
          email: `host-${hostUserId}@me-events.test`,
          displayName: 'Host User',
        },
        {
          id: otherUserId,
          email: `other-${otherUserId}@me-events.test`,
          displayName: 'Other User',
        },
      ],
    });

    // Both users need verified email to pass requireVerifiedEmail
    await db.user.updateMany({
      where: { id: { in: [hostUserId, otherUserId] } },
      data: { emailVerifiedAt: new Date() },
    });

    const issuedHost = await tokens.issue({
      userId: hostUserId,
      email: `host-${hostUserId}@me-events.test`,
    });
    hostToken = issuedHost.value;

    // Seed events
    const now = new Date();
    hostEventId1 = createId();
    hostEventId2 = createId();
    otherEventId = createId();
    await db.event.createMany({
      data: [
        {
          id: hostEventId1,
          hostUserId,
          title: 'Host Event 1',
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
          id: hostEventId2,
          hostUserId,
          title: 'Host Event 2',
          description: null,
          venueAddress: '2 Raffles Quay, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.281,
          venueLongitude: 103.851,
          startsAt: new Date(now.getTime() + 8 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() + 8 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
          capacity: 8,
          category: 'drinks',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'published',
          cancellationReason: null,
          createdAt: new Date(now.getTime() + 1),
          updatedAt: new Date(now.getTime() + 1),
        },
        {
          id: otherEventId,
          hostUserId: otherUserId,
          title: 'Other Event',
          description: null,
          venueAddress: '3 Raffles Quay, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.282,
          venueLongitude: 103.852,
          startsAt: new Date(now.getTime() + 9 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() + 9 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
          capacity: 5,
          category: 'hike',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'published',
          cancellationReason: null,
          createdAt: new Date(now.getTime() + 2),
          updatedAt: new Date(now.getTime() + 2),
        },
      ],
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.event
      .deleteMany({ where: { id: { in: [hostEventId1, hostEventId2, otherEventId] } } })
      .catch(() => null);
    await db.user
      .deleteMany({ where: { id: { in: [hostUserId, otherUserId] } } })
      .catch(() => null);
    await db.$disconnect();
  });

  it('returns 401 without Authorization header', async () => {
    const { app } = buildApp();
    const res = await app.request('/me/events');
    expect(res.status).toBe(401);
  });

  it("returns only the authenticated user's hosted events", async () => {
    const { app } = buildApp();
    const res = await app.request('/me/events', {
      headers: { Authorization: `Bearer ${hostToken}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      events: Array<{ id: string; hostUserId: string; title: string }>;
      nextCursor: string | null;
    };
    const ids = body.events.map((e) => e.id);
    expect(ids).toContain(hostEventId1);
    expect(ids).toContain(hostEventId2);
    expect(ids).not.toContain(otherEventId);
    // All returned events have the correct hostUserId
    for (const event of body.events) {
      expect(event.hostUserId).toBe(hostUserId);
    }
  });

  it('returns empty array when authenticated user hosts no events', async () => {
    // otherToken belongs to a user who has no events in the host-events list
    // We use a fresh third user who hasn't created any events.
    // Actually, otherUserId did create otherEventId. Use a different seeded
    // approach: assert that otherToken only sees "Other Event" (not host events).
    // Re-test the cleaner way: create a user with no events.
    const noEventsUserId = createId();
    await db.user.create({
      data: {
        id: noEventsUserId,
        email: `noevents-${noEventsUserId}@me-events.test`,
        displayName: 'No Events User',
        emailVerifiedAt: new Date(),
      },
    });
    const tokens = new JwtAccessTokenIssuer();
    const noEventsToken = (
      await tokens.issue({
        userId: noEventsUserId,
        email: `noevents-${noEventsUserId}@me-events.test`,
      })
    ).value;

    try {
      const { app } = buildApp();
      const res = await app.request('/me/events', {
        headers: { Authorization: `Bearer ${noEventsToken}` },
      });
      expect(res.status).toBe(200);
      const body = (await res.json()) as { events: unknown[]; nextCursor: string | null };
      expect(body.events).toHaveLength(0);
      expect(body.nextCursor).toBeNull();
    } finally {
      await db.user.delete({ where: { id: noEventsUserId } }).catch(() => null);
    }
  });
});
