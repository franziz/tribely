// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { JwtAccessTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-access-token-issuer.js';
import { FakeFileStorage } from '@/features/events/application/usecases/fakes.js';
import { buildApp } from '../../../../../app.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * HTTP-level integration tests for TRI-306 replace-cover-photo endpoint:
 *
 * PUT /events/:id/cover-photo
 *
 * AC4: new key persists → new coverPhotoUrl surfaces in response.
 * AC6: host-only enforced server-side; non-host request rejected with 403.
 * AC3/AC5: body requires non-null key — missing/empty body rejected with 400.
 */
describe.skipIf(!dbUrl)('PUT /events/:id/cover-photo (integration)', () => {
  let db: PrismaClient;
  let tokens: JwtAccessTokenIssuer;
  let hostUserId: string;
  let hostToken: string;
  let nonHostUserId: string;
  let nonHostToken: string;
  let eventId: string;
  let initialKey: string;

  const now = new Date();
  const futureStart = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  const futureEnd = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000);

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    tokens = new JwtAccessTokenIssuer();

    // Seed host user (full verification to pass guards on the route)
    hostUserId = createId();
    const hostEmail = `replace-cover-host-${hostUserId}@test.local`;
    await db.user.create({
      data: {
        id: hostUserId,
        email: hostEmail,
        displayName: 'Replace Cover Host',
        emailVerifiedAt: new Date(),
        phoneVerifiedAt: new Date(),
        selfieStatus: 'approved',
      },
    });
    const issuedHost = await tokens.issue({ userId: hostUserId, email: hostEmail });
    hostToken = issuedHost.value;

    // Seed non-host user (also fully verified, so 403 comes from ownership check, not auth gates)
    nonHostUserId = createId();
    const nonHostEmail = `replace-cover-nonhost-${nonHostUserId}@test.local`;
    await db.user.create({
      data: {
        id: nonHostUserId,
        email: nonHostEmail,
        displayName: 'Replace Cover Non-Host',
        emailVerifiedAt: new Date(),
        phoneVerifiedAt: new Date(),
        selfieStatus: 'approved',
      },
    });
    const issuedNonHost = await tokens.issue({ userId: nonHostUserId, email: nonHostEmail });
    nonHostToken = issuedNonHost.value;

    // Seed a published event owned by the host
    eventId = createId();
    initialKey = `events/${hostUserId}/${createId()}.jpg`;
    await db.event.create({
      data: {
        id: eventId,
        hostUserId,
        title: 'Replace Cover Photo Test Event',
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
        coverPhotoStorageKey: initialKey,
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
    await db.event.deleteMany({ where: { hostUserId } }).catch(() => null);
    await db.user.delete({ where: { id: hostUserId } }).catch(() => null);
    await db.user.delete({ where: { id: nonHostUserId } }).catch(() => null);
    await db.$disconnect();
  });

  it('returns 401 when unauthenticated', async () => {
    const { app } = buildApp();
    const res = await app.request(`/events/${eventId}/cover-photo`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ coverPhotoStorageKey: `events/${hostUserId}/x.jpg` }),
    });
    expect(res.status).toBe(401);
  });

  // AC6: 403 for a non-host authenticated caller (server-side enforcement)
  it('returns 403 for a non-host authenticated caller (AC6)', async () => {
    const { app } = buildApp();
    const res = await app.request(`/events/${eventId}/cover-photo`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${nonHostToken}`,
        'Content-Type': 'application/json',
      },
      // Key scoped to the non-host — prefix check fires AFTER host ownership check
      body: JSON.stringify({ coverPhotoStorageKey: `events/${nonHostUserId}/new.jpg` }),
    });
    expect(res.status).toBe(403);
  });

  it('returns 400 on missing body (AC3)', async () => {
    const { app } = buildApp();
    const res = await app.request(`/events/${eventId}/cover-photo`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${hostToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(400);
  });

  it('returns 400 on empty coverPhotoStorageKey (AC3)', async () => {
    const { app } = buildApp();
    const res = await app.request(`/events/${eventId}/cover-photo`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${hostToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ coverPhotoStorageKey: '' }),
    });
    expect(res.status).toBe(400);
  });

  // AC4: new key persists → new coverPhotoUrl surfaces in response
  it('returns 200 with updated coverPhotoUrl for the host (AC4)', async () => {
    const { app } = buildApp();
    const newKey = `events/${hostUserId}/${createId()}.jpg`;
    const res = await app.request(`/events/${eventId}/cover-photo`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${hostToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ coverPhotoStorageKey: newKey }),
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    // coverPhotoUrl is a non-null string (resolved from the storage key)
    expect(typeof body.coverPhotoUrl).toBe('string');
    expect(body.coverPhotoUrl).not.toBeNull();
    // The event id and status are also present
    expect(body.id).toBe(eventId);
    expect(body.status).toBe('published');
  });

  it('returns 409 when the event is cancelled', async () => {
    if (!dbUrl) return;
    // Seed a second event and cancel it
    const cancelledId = createId();
    await db.event.create({
      data: {
        id: cancelledId,
        hostUserId,
        title: 'Cancelled event for cover test',
        description: null,
        venueAddress: '1 Harbourfront Walk',
        venueCity: 'Singapore',
        venueLatitude: 1.2631,
        venueLongitude: 103.8226,
        venueCategory: 'cafe',
        startsAt: futureStart,
        endsAt: futureEnd,
        capacity: 6,
        category: 'food',
        costNotes: null,
        coverPhotoStorageKey: null,
        approvalMode: 'manual',
        status: 'cancelled',
        cancellationReason: 'Test cancellation',
        createdAt: now,
        updatedAt: now,
      },
    });

    const { app } = buildApp();
    const res = await app.request(`/events/${cancelledId}/cover-photo`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${hostToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ coverPhotoStorageKey: `events/${hostUserId}/new.jpg` }),
    });
    expect(res.status).toBe(409);

    await db.event.delete({ where: { id: cancelledId } }).catch(() => null);
  });

  it('returns 422 COVER_PHOTO_TOO_LARGE when the new cover photo exceeds the byte cap', async () => {
    if (!dbUrl) return;
    const oversizedKey = `events/${hostUserId}/oversized-replacement.jpg`;
    const fileStorage = new FakeFileStorage();
    fileStorage.setSize(oversizedKey, 5_242_881);
    const { app } = buildApp({ fileStorage });

    const res = await app.request(`/events/${eventId}/cover-photo`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${hostToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ coverPhotoStorageKey: oversizedKey }),
    });

    expect(res.status).toBe(422);
    const body = (await res.json()) as {
      error: { code: string; details: { subcode: string; maxBytes: number; actualBytes: number } };
    };
    expect(body.error.code).toBe('UNPROCESSABLE');
    expect(body.error.details.subcode).toBe('COVER_PHOTO_TOO_LARGE');
    expect(body.error.details.maxBytes).toBe(5_242_880);
    expect(body.error.details.actualBytes).toBe(5_242_881);

    // Original key must remain unchanged in the DB.
    const saved = await db.event.findUnique({ where: { id: eventId } });
    expect(saved?.coverPhotoStorageKey).toBe(initialKey);
  });
});
