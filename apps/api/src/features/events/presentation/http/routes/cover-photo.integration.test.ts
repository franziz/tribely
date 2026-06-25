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
 * HTTP-level integration tests for TRI-49 cover photo upload:
 *
 * 1. POST /events/cover-photo returns { uploadUrl, storageKey } scoped to
 *    the authenticated host's `events/<userId>/` prefix.
 * 2. A created event's GET /events/:id response includes a `coverPhotoUrl`
 *    field (null when no key supplied, non-null string when key supplied).
 */
describe.skipIf(!dbUrl)('POST /events/cover-photo (integration)', () => {
  let db: PrismaClient;
  let tokens: JwtAccessTokenIssuer;
  let hostUserId: string;
  let hostToken: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    tokens = new JwtAccessTokenIssuer();

    hostUserId = createId();
    const hostEmail = `cover-photo-test-${hostUserId}@test.local`;
    await db.user.create({
      data: {
        id: hostUserId,
        email: hostEmail,
        displayName: 'Cover Photo Test Host',
        emailVerifiedAt: new Date(),
        phoneVerifiedAt: new Date(),
        selfieStatus: 'approved',
      },
    });
    const issued = await tokens.issue({ userId: hostUserId, email: hostEmail });
    hostToken = issued.value;
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // Clean up events created by this test (host FK absent — safe to delete user directly).
    await db.event.deleteMany({ where: { hostUserId } }).catch(() => null);
    await db.user.delete({ where: { id: hostUserId } }).catch(() => null);
    await db.$disconnect();
  });

  it('returns 401 when unauthenticated', async () => {
    const { app } = buildApp();
    const res = await app.request('/events/cover-photo?contentType=image/jpeg', {
      method: 'POST',
    });
    expect(res.status).toBe(401);
  });

  it('returns { uploadUrl, storageKey } scoped to the host prefix', async () => {
    const { app } = buildApp();
    const res = await app.request('/events/cover-photo?contentType=image/jpeg', {
      method: 'POST',
      headers: { Authorization: `Bearer ${hostToken}` },
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { uploadUrl: unknown; storageKey: unknown };
    expect(typeof body.uploadUrl).toBe('string');
    expect(typeof body.storageKey).toBe('string');

    // Key MUST be scoped to this host's prefix (security-critical).
    expect((body.storageKey as string).startsWith(`events/${hostUserId}/`)).toBe(true);
    expect(body.storageKey as string).toMatch(/\.(jpg|png|webp)$/);
  });

  it('returns 400 when contentType is missing', async () => {
    const { app } = buildApp();
    const res = await app.request('/events/cover-photo', {
      method: 'POST',
      headers: { Authorization: `Bearer ${hostToken}` },
    });

    expect(res.status).toBe(400);
  });

  it('returns 400 for unsupported contentType', async () => {
    const { app } = buildApp();
    const res = await app.request('/events/cover-photo?contentType=image/gif', {
      method: 'POST',
      headers: { Authorization: `Bearer ${hostToken}` },
    });

    expect(res.status).toBe(400);
  });
});

describe.skipIf(!dbUrl)('Event response includes coverPhotoUrl (integration)', () => {
  let db: PrismaClient;
  let tokens: JwtAccessTokenIssuer;
  let hostUserId: string;
  let eventWithoutPhotoId: string;
  let eventWithPhotoId: string;

  const now = new Date();
  const futureStart = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  const futureEnd = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000);

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    tokens = new JwtAccessTokenIssuer();

    hostUserId = createId();
    const hostEmail = `cover-photo-response-test-${hostUserId}@test.local`;
    await db.user.create({
      data: {
        id: hostUserId,
        email: hostEmail,
        displayName: 'Cover Photo Response Host',
        emailVerifiedAt: new Date(),
        phoneVerifiedAt: new Date(),
        selfieStatus: 'approved',
      },
    });
    await tokens.issue({ userId: hostUserId, email: hostEmail });

    // Seed event without cover photo
    eventWithoutPhotoId = createId();
    await db.event.create({
      data: {
        id: eventWithoutPhotoId,
        hostUserId,
        title: 'Event Without Cover Photo',
        description: null,
        venueAddress: '18 Raffles Quay',
        venueCity: 'Singapore',
        venueLatitude: 1.2806,
        venueLongitude: 103.8504,
        venueCategory: 'cafe',
        startsAt: futureStart,
        endsAt: futureEnd,
        capacity: 6,
        category: 'food',
        costNotes: null,
        coverPhotoStorageKey: null,
        approvalMode: 'manual',
        status: 'published',
        cancellationReason: null,
        createdAt: now,
        updatedAt: now,
      },
    });

    // Seed event with a cover photo key (storage key — read URL resolved by the controller)
    eventWithPhotoId = createId();
    await db.event.create({
      data: {
        id: eventWithPhotoId,
        hostUserId,
        title: 'Event With Cover Photo',
        description: null,
        venueAddress: '1 Harbourfront Walk',
        venueCity: 'Singapore',
        venueLatitude: 1.2631,
        venueLongitude: 103.8226,
        venueCategory: 'cafe',
        startsAt: new Date(futureStart.getTime() + 60 * 60 * 1000),
        endsAt: new Date(futureEnd.getTime() + 60 * 60 * 1000),
        capacity: 6,
        category: 'food',
        costNotes: null,
        coverPhotoStorageKey: `events/${hostUserId}/${createId()}.jpg`,
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
    await db.event.delete({ where: { id: eventWithoutPhotoId } }).catch(() => null);
    await db.event.delete({ where: { id: eventWithPhotoId } }).catch(() => null);
    await db.user.delete({ where: { id: hostUserId } }).catch(() => null);
    await db.$disconnect();
  });

  it('GET /events/:id returns coverPhotoUrl: null when no key set', async () => {
    const { app } = buildApp();
    const res = await app.request(`/events/${eventWithoutPhotoId}`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { event: Record<string, unknown> };
    expect('coverPhotoUrl' in body.event).toBe(true);
    expect(body.event.coverPhotoUrl).toBeNull();
  });

  it('GET /events/:id returns coverPhotoUrl: string (resolved URL) when key is set', async () => {
    const { app } = buildApp();
    const res = await app.request(`/events/${eventWithPhotoId}`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { event: Record<string, unknown> };
    expect('coverPhotoUrl' in body.event).toBe(true);
    // With LoggingFileStorage (STORAGE_TRANSPORT default), getSignedUrl returns
    // a logging stub URL — just verify it is a non-null string.
    expect(typeof body.event.coverPhotoUrl).toBe('string');
  });

  it('GET /events returns coverPhotoUrl on each event in the listing', async () => {
    const { app } = buildApp();
    const res = await app.request(`/events?hostUserId=${hostUserId}`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { events: Record<string, unknown>[] };
    expect(body.events.length).toBeGreaterThanOrEqual(2);
    for (const event of body.events) {
      expect('coverPhotoUrl' in event).toBe(true);
    }
  });
});
