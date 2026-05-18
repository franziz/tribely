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
 * HTTP-level integration test for `host.isVerified` on GET /events/:id.
 *
 * AC5 anchor (CEO 2026-05-14 verdict, TRI-86 §1 §4): no code path may resolve
 * `isVerified: true` for a production host until TRI-16 (phone) and TRI-23
 * (selfie) ship. The use case hardcodes `phoneVerifiedAt: null, selfieApprovedAt:
 * null` — so even an email-verified host returns `false` under the default
 * signal set `['email','phone','selfie']`.
 *
 * Cases (§10.3):
 *   1. Host with emailVerifiedAt null → host.isVerified: false, field present.
 *   2. Host with emailVerifiedAt set → host.isVerified: false (AC5 anchor).
 *   3. Field is always present and always boolean in both cases.
 *   4. Cross-projection consistency: GET /events/:id host.isVerified matches
 *      GET /users/:id isVerified for the same host at the same moment.
 */
describe.skipIf(!dbUrl)('GET /events/:id — host.isVerified field (integration)', () => {
  let db: PrismaClient;
  let tokens: JwtAccessTokenIssuer;

  let unverifiedHostId: string;
  let unverifiedHostToken: string;
  let unverifiedEventId: string;

  let emailVerifiedHostId: string;
  let emailVerifiedHostToken: string;
  let emailVerifiedEventId: string;

  const now = new Date();
  const futureStart = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  const futureEnd = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000);

  const seedEvent = async (eventId: string, hostUserId: string): Promise<void> => {
    await db.event.create({
      data: {
        id: eventId,
        hostUserId,
        title: 'Integration Test Event',
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
        costSplit: 'own',
        approvalMode: 'manual',
        status: 'published',
        cancellationReason: null,
        createdAt: now,
        updatedAt: now,
      },
    });
  };

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    tokens = new JwtAccessTokenIssuer();

    // Seed 1: host with no email verification
    unverifiedHostId = createId();
    const unverifiedEmail = `get-event-isverified-unverified-${unverifiedHostId}@test.local`;
    await db.user.create({
      data: {
        id: unverifiedHostId,
        email: unverifiedEmail,
        displayName: 'Unverified Host',
        emailVerifiedAt: null,
      },
    });
    const issuedUnverified = await tokens.issue({
      userId: unverifiedHostId,
      email: unverifiedEmail,
    });
    unverifiedHostToken = issuedUnverified.value;
    unverifiedEventId = createId();
    await seedEvent(unverifiedEventId, unverifiedHostId);

    // Seed 2: host with email verified
    emailVerifiedHostId = createId();
    const emailVerifiedEmail = `get-event-isverified-emailverified-${emailVerifiedHostId}@test.local`;
    await db.user.create({
      data: {
        id: emailVerifiedHostId,
        email: emailVerifiedEmail,
        displayName: 'Email Verified Host',
        emailVerifiedAt: new Date(),
      },
    });
    const issuedEmailVerified = await tokens.issue({
      userId: emailVerifiedHostId,
      email: emailVerifiedEmail,
    });
    emailVerifiedHostToken = issuedEmailVerified.value;
    emailVerifiedEventId = createId();
    await seedEvent(emailVerifiedEventId, emailVerifiedHostId);
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // Events must be deleted before users (FK constraint).
    await db.event.delete({ where: { id: unverifiedEventId } }).catch(() => null);
    await db.event.delete({ where: { id: emailVerifiedEventId } }).catch(() => null);
    await db.user.delete({ where: { id: unverifiedHostId } }).catch(() => null);
    await db.user.delete({ where: { id: emailVerifiedHostId } }).catch(() => null);
    await db.$disconnect();
  });

  it('returns host.isVerified: false for a host with emailVerifiedAt null', async () => {
    const { app } = buildApp();
    const res = await app.request(`/events/${unverifiedEventId}`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { host: { isVerified: unknown } };
    expect(body.host.isVerified).toBe(false);
    expect(typeof body.host.isVerified).toBe('boolean');
  });

  it('returns host.isVerified: false even when emailVerifiedAt is set (AC5 anchor: phone+selfie signals null)', async () => {
    const { app } = buildApp();
    const res = await app.request(`/events/${emailVerifiedEventId}`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { host: { isVerified: unknown } };
    // AC5: until TRI-16 (phone) and TRI-23 (selfie) ship, phoneVerifiedAt and
    // selfieApprovedAt are hardcoded null in GetEventUseCase — so even an
    // email-verified host does not pass all three signals.
    expect(body.host.isVerified).toBe(false);
    expect(typeof body.host.isVerified).toBe('boolean');
  });

  it('host.isVerified field is always present and boolean in both seeded cases', async () => {
    const { app } = buildApp();

    const res1 = await app.request(`/events/${unverifiedEventId}`);
    const body1 = (await res1.json()) as { host: Record<string, unknown> };
    expect('isVerified' in body1.host).toBe(true);
    expect(typeof body1.host.isVerified).toBe('boolean');

    const res2 = await app.request(`/events/${emailVerifiedEventId}`);
    const body2 = (await res2.json()) as { host: Record<string, unknown> };
    expect('isVerified' in body2.host).toBe(true);
    expect(typeof body2.host.isVerified).toBe('boolean');
  });

  it('GET /events/:id host.isVerified matches GET /users/:id isVerified for the same host (cross-projection consistency, spec §10.3 case 2)', async () => {
    const { app } = buildApp();

    // Unverified host
    const eventRes1 = await app.request(`/events/${unverifiedEventId}`);
    const eventBody1 = (await eventRes1.json()) as { host: { isVerified: unknown } };

    const userRes1 = await app.request(`/users/${unverifiedHostId}`, {
      headers: { Authorization: `Bearer ${unverifiedHostToken}` },
    });
    const userBody1 = (await userRes1.json()) as { isVerified: unknown };

    expect(eventBody1.host.isVerified).toBe(userBody1.isVerified);

    // Email-verified host
    const eventRes2 = await app.request(`/events/${emailVerifiedEventId}`);
    const eventBody2 = (await eventRes2.json()) as { host: { isVerified: unknown } };

    const userRes2 = await app.request(`/users/${emailVerifiedHostId}`, {
      headers: { Authorization: `Bearer ${emailVerifiedHostToken}` },
    });
    const userBody2 = (await userRes2.json()) as { isVerified: unknown };

    expect(eventBody2.host.isVerified).toBe(userBody2.isVerified);
  });
});
