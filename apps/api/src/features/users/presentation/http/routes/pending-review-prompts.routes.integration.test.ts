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
 * HTTP-level integration tests for GET /me/pending-review-prompts.
 *
 * Exercises the full stack: JWT auth → route → use case → repositories → DB.
 * Skipped when DATABASE_URL is unset (CI placeholders, unit-test-only runs).
 */
describe.skipIf(!dbUrl)('GET /me/pending-review-prompts (integration)', () => {
  let db: PrismaClient;
  let tokens: JwtAccessTokenIssuer;

  // Viewer (the authenticated user requesting the prompt)
  let viewerId: string;
  let viewerToken: string;
  let viewerUnverifiedId: string;
  let viewerUnverifiedToken: string;

  // Counterparts
  let hostId: string;
  let guestAId: string;
  let guestBId: string;
  let blockedHostId: string;

  // Timestamps: all relative to "now" at test-seed time.
  // We seed endsAt in the past so the use case window logic works:
  //   - "too recent" events ended < 24h ago → excluded
  //   - "too old" events ended > 7d ago → excluded
  //   - "eligible" events ended 2d ago and 3d ago → inside the window
  const SEED_NOW = new Date();
  const endsAt2dAgo = new Date(SEED_NOW.getTime() - 2 * 24 * 60 * 60 * 1000);
  const endsAt3dAgo = new Date(SEED_NOW.getTime() - 3 * 24 * 60 * 60 * 1000);
  const endsAt30minAgo = new Date(SEED_NOW.getTime() - 30 * 60 * 1000);
  const endsAt8dAgo = new Date(SEED_NOW.getTime() - 8 * 24 * 60 * 60 * 1000);
  const startsAtBase = new Date(SEED_NOW.getTime() - 10 * 24 * 60 * 60 * 1000);

  // Track seeded IDs for cleanup.
  const seededEventIds: string[] = [];

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    tokens = new JwtAccessTokenIssuer();

    viewerId = createId();
    viewerUnverifiedId = createId();
    hostId = createId();
    guestAId = createId();
    guestBId = createId();
    blockedHostId = createId();

    await db.user.createMany({
      data: [
        {
          id: viewerId,
          email: `prp-viewer-${viewerId}@test.local`,
          displayName: 'Viewer',
          emailVerifiedAt: new Date(),
        },
        {
          id: viewerUnverifiedId,
          email: `prp-unverified-${viewerUnverifiedId}@test.local`,
          displayName: 'Unverified',
        },
        {
          id: hostId,
          email: `prp-host-${hostId}@test.local`,
          displayName: 'TheHost',
          avatarUrl: 'https://example.com/host.jpg',
        },
        {
          id: guestAId,
          email: `prp-guesta-${guestAId}@test.local`,
          displayName: 'GuestA',
        },
        {
          id: guestBId,
          email: `prp-guestb-${guestBId}@test.local`,
          displayName: 'GuestB',
        },
        {
          id: blockedHostId,
          email: `prp-blockedhost-${blockedHostId}@test.local`,
          displayName: 'BlockedHost',
        },
      ],
    });

    const issued = await tokens.issue({
      userId: viewerId,
      email: `prp-viewer-${viewerId}@test.local`,
    });
    viewerToken = issued.value;

    const issuedUnverified = await tokens.issue({
      userId: viewerUnverifiedId,
      email: `prp-unverified-${viewerUnverifiedId}@test.local`,
    });
    viewerUnverifiedToken = issuedUnverified.value;

    // ── Event: viewer is HOST, ended 2d ago (oldest eligible host event)
    //    Counterparts: guestA (approved), guestB (approved)
    const hostEvent2d = createId();
    seededEventIds.push(hostEvent2d);
    await db.event.create({
      data: {
        id: hostEvent2d,
        hostUserId: viewerId,
        title: 'Host Event 2d ago',
        venueAddress: '1 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: startsAtBase,
        endsAt: endsAt2dAgo,
        capacity: 5,
        category: 'food',
        venueCategory: 'cafe',
        costNotes: null,
        approvalMode: 'manual',
        status: 'completed',
      },
    });
    await db.joinRequest.createMany({
      data: [
        {
          id: createId(),
          eventId: hostEvent2d,
          requesterUserId: guestAId,
          status: 'approved',
          requestedAt: new Date(),
        },
        {
          id: createId(),
          eventId: hostEvent2d,
          requesterUserId: guestBId,
          status: 'approved',
          requestedAt: new Date(),
        },
      ],
    });

    // ── Event: viewer is JOINER, ended 3d ago (older than host event above)
    //    Counterpart: hostId
    const joinerEvent3d = createId();
    seededEventIds.push(joinerEvent3d);
    await db.event.create({
      data: {
        id: joinerEvent3d,
        hostUserId: hostId,
        title: 'Joiner Event 3d ago',
        venueAddress: '2 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: startsAtBase,
        endsAt: endsAt3dAgo,
        capacity: 5,
        category: 'food',
        venueCategory: 'cafe',
        costNotes: null,
        approvalMode: 'manual',
        status: 'completed',
      },
    });
    await db.joinRequest.create({
      data: {
        id: createId(),
        eventId: joinerEvent3d,
        requesterUserId: viewerId,
        status: 'approved',
        requestedAt: new Date(),
      },
    });

    // ── Event: viewer is JOINER, ended < 24h ago → too recent → excluded
    const tooRecentEvent = createId();
    seededEventIds.push(tooRecentEvent);
    await db.event.create({
      data: {
        id: tooRecentEvent,
        hostUserId: hostId,
        title: 'Too Recent Event',
        venueAddress: '3 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: startsAtBase,
        endsAt: endsAt30minAgo,
        capacity: 5,
        category: 'food',
        venueCategory: 'cafe',
        costNotes: null,
        approvalMode: 'manual',
        status: 'completed',
      },
    });
    await db.joinRequest.create({
      data: {
        id: createId(),
        eventId: tooRecentEvent,
        requesterUserId: viewerId,
        status: 'approved',
        requestedAt: new Date(),
      },
    });

    // ── Event: viewer is JOINER, ended > 7d ago → expired → excluded
    const tooOldEvent = createId();
    seededEventIds.push(tooOldEvent);
    await db.event.create({
      data: {
        id: tooOldEvent,
        hostUserId: hostId,
        title: 'Too Old Event',
        venueAddress: '4 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: startsAtBase,
        endsAt: endsAt8dAgo,
        capacity: 5,
        category: 'food',
        venueCategory: 'cafe',
        costNotes: null,
        approvalMode: 'manual',
        status: 'completed',
      },
    });
    await db.joinRequest.create({
      data: {
        id: createId(),
        eventId: tooOldEvent,
        requesterUserId: viewerId,
        status: 'approved',
        requestedAt: new Date(),
      },
    });

    // ── Event: viewer is JOINER, host is blocked, ended 2d ago → excluded
    const blockedEvent = createId();
    seededEventIds.push(blockedEvent);
    await db.event.create({
      data: {
        id: blockedEvent,
        hostUserId: blockedHostId,
        title: 'Blocked Host Event',
        venueAddress: '5 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: startsAtBase,
        endsAt: endsAt2dAgo,
        capacity: 5,
        category: 'food',
        venueCategory: 'cafe',
        costNotes: null,
        approvalMode: 'manual',
        status: 'completed',
      },
    });
    await db.joinRequest.create({
      data: {
        id: createId(),
        eventId: blockedEvent,
        requesterUserId: viewerId,
        status: 'approved',
        requestedAt: new Date(),
      },
    });
    // Block: viewer blocked blockedHostId
    await db.userBlock.create({
      data: {
        id: createId(),
        initiatorUserId: viewerId,
        blockedUserId: blockedHostId,
        createdAt: new Date(),
      },
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // Clean up in FK-safe order.
    await db.review.deleteMany({
      where: { raterUserId: viewerId },
    });
    await db.userBlock.deleteMany({
      where: {
        OR: [{ initiatorUserId: viewerId }, { initiatorUserId: blockedHostId }],
      },
    });
    await db.joinRequest.deleteMany({
      where: {
        OR: [{ requesterUserId: viewerId }, { eventId: { in: seededEventIds } }],
      },
    });
    await db.event.deleteMany({ where: { id: { in: seededEventIds } } });
    await db.user.deleteMany({
      where: {
        id: {
          in: [viewerId, viewerUnverifiedId, hostId, guestAId, guestBId, blockedHostId],
        },
      },
    });
    await db.$disconnect();
  });

  it('401 — no auth token', async () => {
    const { app } = buildApp();
    const res = await app.request('/me/pending-review-prompts');
    expect(res.status).toBe(401);
  });

  it('403 — unverified email', async () => {
    const { app } = buildApp();
    const res = await app.request('/me/pending-review-prompts', {
      headers: { Authorization: `Bearer ${viewerUnverifiedToken}` },
    });
    expect(res.status).toBe(403);
  });

  it('returns null when no eligible events in window', async () => {
    // Use a brand-new user with no events at all.
    if (!dbUrl) return;
    const freshUserId = createId();
    await db.user.create({
      data: {
        id: freshUserId,
        email: `prp-fresh-${freshUserId}@test.local`,
        displayName: 'Fresh',
        emailVerifiedAt: new Date(),
      },
    });
    const issued = await tokens.issue({
      userId: freshUserId,
      email: `prp-fresh-${freshUserId}@test.local`,
    });

    const { app } = buildApp();
    const res = await app.request('/me/pending-review-prompts', {
      headers: { Authorization: `Bearer ${issued.value}` },
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { prompt: null };
    expect(body.prompt).toBeNull();

    await db.user.delete({ where: { id: freshUserId } });
  });

  it('event ended < 24h ago — not in prompt (window not opened yet)', async () => {
    // With all events present, the too-recent event for viewerId should not
    // appear in the prompt; the oldest eligible should be returned instead
    // (the joiner event 3d ago — host is hostId).
    const { app } = buildApp();
    const res = await app.request('/me/pending-review-prompts', {
      headers: { Authorization: `Bearer ${viewerToken}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      prompt: { eventTitle: string; ratedUserId: string } | null;
    };
    expect(body.prompt).not.toBeNull();
    // "Too Recent Event" host (hostId) must NOT be the prompt solely because
    // of the < 24h gate — the 3d-ago event host is eligible and older.
    // The too-recent event's endsAt is < 24h ago so it is excluded entirely.
    // The expected prompt is the oldest eligible: joiner-event-3d → hostId.
    expect(body.prompt?.eventTitle).toBe('Joiner Event 3d ago');
    expect(body.prompt?.ratedUserId).toBe(hostId);
  });

  it('event ended > 7d ago — not in prompt (expired)', async () => {
    // The too-old event ended 8d ago; it must never be the prompt.
    // Verified above implicitly (prompt is from 3d-ago event not 8d-ago).
    // This test seeds a viewer with ONLY the too-old event to isolate the gate.
    if (!dbUrl) return;
    const isolatedViewerId = createId();
    await db.user.create({
      data: {
        id: isolatedViewerId,
        email: `prp-iso-${isolatedViewerId}@test.local`,
        displayName: 'Isolated',
        emailVerifiedAt: new Date(),
      },
    });
    const isolatedEventId = createId();
    await db.event.create({
      data: {
        id: isolatedEventId,
        hostUserId: hostId,
        title: 'Expired Event Only',
        venueAddress: '10 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: startsAtBase,
        endsAt: endsAt8dAgo,
        capacity: 5,
        category: 'food',
        venueCategory: 'cafe',
        costNotes: null,
        approvalMode: 'manual',
        status: 'completed',
      },
    });
    await db.joinRequest.create({
      data: {
        id: createId(),
        eventId: isolatedEventId,
        requesterUserId: isolatedViewerId,
        status: 'approved',
        requestedAt: new Date(),
      },
    });
    const issued = await tokens.issue({
      userId: isolatedViewerId,
      email: `prp-iso-${isolatedViewerId}@test.local`,
    });

    const { app } = buildApp();
    const res = await app.request('/me/pending-review-prompts', {
      headers: { Authorization: `Bearer ${issued.value}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { prompt: null };
    expect(body.prompt).toBeNull();

    // Cleanup
    await db.joinRequest.deleteMany({ where: { eventId: isolatedEventId } });
    await db.event.delete({ where: { id: isolatedEventId } });
    await db.user.delete({ where: { id: isolatedViewerId } });
  });

  it('already reviewed counterpart — excluded from prompt', async () => {
    // Viewer reviews the host from the 3d-ago joiner event.
    // Now the oldest eligible should shift to the 2d-ago host event → guestAId
    // (guestAId sorts before guestBId lexicographically).
    if (!dbUrl) return;
    const [event3dRow] = await db.event.findMany({
      where: { hostUserId: hostId, title: 'Joiner Event 3d ago' },
    });
    if (!event3dRow) throw new Error('Seeded event not found');

    const reviewId = createId();
    await db.review.create({
      data: {
        id: reviewId,
        eventId: event3dRow.id,
        raterUserId: viewerId,
        ratedUserId: hostId,
        rating: 5,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    });

    const { app } = buildApp();
    const res = await app.request('/me/pending-review-prompts', {
      headers: { Authorization: `Bearer ${viewerToken}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      prompt: { ratedUserId: string; eventTitle: string } | null;
    };
    expect(body.prompt).not.toBeNull();
    // The reviewed host should be excluded; next oldest eligible is the 2d-ago
    // host event. guestAId vs guestBId: deterministic by ID sort.
    expect(body.prompt?.ratedUserId).not.toBe(hostId);
    expect(body.prompt?.eventTitle).toBe('Host Event 2d ago');

    // Cleanup: remove the review so subsequent tests see the original state.
    await db.review.delete({ where: { id: reviewId } });
  });

  it('counterpart blocked — excluded from prompt', async () => {
    // The blockedHostId event is excluded because viewerId blocked blockedHostId.
    // This is verified implicitly by the main happy-path test above, which returns
    // the 3d-ago event (not the blockedHostId event).
    // Isolate the verification: seed a viewer with ONLY the blocked event.
    if (!dbUrl) return;
    const isolatedViewerId2 = createId();
    await db.user.create({
      data: {
        id: isolatedViewerId2,
        email: `prp-iso2-${isolatedViewerId2}@test.local`,
        displayName: 'IsolatedBlocked',
        emailVerifiedAt: new Date(),
      },
    });
    const blockId2 = createId();
    const blockOnlyEventId = createId();
    await db.event.create({
      data: {
        id: blockOnlyEventId,
        hostUserId: blockedHostId,
        title: 'Blocked Only Event',
        venueAddress: '20 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: startsAtBase,
        endsAt: endsAt2dAgo,
        capacity: 5,
        category: 'food',
        venueCategory: 'cafe',
        costNotes: null,
        approvalMode: 'manual',
        status: 'completed',
      },
    });
    await db.joinRequest.create({
      data: {
        id: createId(),
        eventId: blockOnlyEventId,
        requesterUserId: isolatedViewerId2,
        status: 'approved',
        requestedAt: new Date(),
      },
    });
    // isolatedViewerId2 blocks blockedHostId
    await db.userBlock.create({
      data: {
        id: blockId2,
        initiatorUserId: isolatedViewerId2,
        blockedUserId: blockedHostId,
        createdAt: new Date(),
      },
    });
    const issued = await tokens.issue({
      userId: isolatedViewerId2,
      email: `prp-iso2-${isolatedViewerId2}@test.local`,
    });

    const { app } = buildApp();
    const res = await app.request('/me/pending-review-prompts', {
      headers: { Authorization: `Bearer ${issued.value}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { prompt: null };
    expect(body.prompt).toBeNull();

    // Cleanup
    await db.userBlock.delete({ where: { id: blockId2 } });
    await db.joinRequest.deleteMany({ where: { eventId: blockOnlyEventId } });
    await db.event.delete({ where: { id: blockOnlyEventId } });
    await db.user.delete({ where: { id: isolatedViewerId2 } });
  });

  it('multiple eligible events — oldest wins (deterministic)', async () => {
    // The 3d-ago event is older than the 2d-ago event; hostId should be returned.
    const { app } = buildApp();
    const res = await app.request('/me/pending-review-prompts', {
      headers: { Authorization: `Bearer ${viewerToken}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      prompt: { eventTitle: string; ratedUserId: string } | null;
    };
    expect(body.prompt?.eventTitle).toBe('Joiner Event 3d ago');
    expect(body.prompt?.ratedUserId).toBe(hostId);
  });

  it('response shape — prompt includes expected fields', async () => {
    const { app } = buildApp();
    const res = await app.request('/me/pending-review-prompts', {
      headers: { Authorization: `Bearer ${viewerToken}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      prompt: {
        eventId: string;
        eventTitle: string;
        eventEndedAt: string;
        ratedUserId: string;
        ratedUserDisplayName: string;
        ratedUserAvatarUrl: string | null;
      } | null;
    };
    expect(body.prompt).not.toBeNull();
    if (!body.prompt) return; // type-narrowing guard (expect above already fails if null)
    const p = body.prompt;
    expect(typeof p.eventId).toBe('string');
    expect(typeof p.eventTitle).toBe('string');
    expect(typeof p.eventEndedAt).toBe('string');
    expect(typeof p.ratedUserId).toBe('string');
    expect(typeof p.ratedUserDisplayName).toBe('string');
    // avatarUrl is nullable — hostId has one set in seed
    expect(p.ratedUserId).toBe(hostId);
    expect(p.ratedUserAvatarUrl).toBe('https://example.com/host.jpg');
  });
});
