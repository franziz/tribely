// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { JwtAccessTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-access-token-issuer.js';
import { buildApp } from '../../../../../app.js';

const validPostBody = () => ({
  title: 'Verification Gate Test Event',
  description: null,
  venue: {
    address: '18 Raffles Quay',
    city: 'Singapore',
    latitude: 1.2806,
    longitude: 103.8504,
    category: 'cafe',
  },
  startsAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
  endsAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000).toISOString(),
  capacity: 6,
  category: 'food',
  approvalMode: 'manual',
});

const dbUrl = process.env.DATABASE_URL;

/**
 * HTTP-level integration test for event CRUD routes (POST /events, PATCH /events/:id,
 * GET /events/:id). Exercises the full stack: JWT auth middleware → route → controller
 * → CreateEvent/UpdateEvent/GetEvent use cases → Prisma repository → DB.
 *
 * Skipped when DATABASE_URL is unset so unit-only runs still pass.
 *
 * Covers TRI-33 Brief 7 acceptance criteria:
 *   1. POST first-time host + private category → 422 FIRST_EVENT_MUST_BE_PUBLIC
 *   2. POST first-time host + public category → 201 + event.venue.category in response
 *   3. POST first-time host + public category + private keyword in name → 422
 *   4. PATCH venue to private category + first-time host → 422
 *   5. GET /events/:id returns event.venue.category
 */
describe.skipIf(!dbUrl)('Event routes — venue.category integration (TRI-33)', () => {
  let db: PrismaClient;
  let token: string;
  let userId: string;

  /**
   * Shared valid future times — reused across creates to avoid clock-skew
   * within the same test file. Each create gets uniquely seeded data so
   * tests don't interfere with each other.
   */
  const futureMs = () => Date.now() + 7 * 24 * 60 * 60 * 1000;

  const validPublicVenueBody = () => ({
    title: 'Hawker Centre Gathering',
    description: null,
    venue: {
      address: '18 Raffles Quay',
      city: 'Singapore',
      latitude: 1.2806,
      longitude: 103.8504,
      category: 'cafe',
    },
    startsAt: new Date(futureMs()).toISOString(),
    endsAt: new Date(futureMs() + 3 * 60 * 60 * 1000).toISOString(),
    capacity: 6,
    category: 'food',
    approvalMode: 'manual',
  });

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    userId = createId();
    const email = `event-routes-${userId}@test.local`;

    // POST /events now requires both email and phone verified (TRI-16 SWE-FIX-C).
    // Phone column has UNIQUE constraint + E.164 validation on mapper read-back;
    // use last-8-digits of a timestamp for a unique Singapore (+65) number.
    await db.user.create({
      data: {
        id: userId,
        email,
        displayName: 'Event Route Test User',
        emailVerifiedAt: new Date(),
        phone: `+65${String(Date.now()).slice(-8)}`,
        phoneVerifiedAt: new Date(),
      },
    });

    const issued = await tokens.issue({ userId, email });
    token = issued.value;
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // User cascade-deletes its owned events.
    await db.user.delete({ where: { id: userId } }).catch(() => null);
    await db.$disconnect();
  });

  // ---- Case 1: POST first-time host + private category → 422 ----

  it('POST /events — private category for first-time host returns 422 FIRST_EVENT_MUST_BE_PUBLIC', async () => {
    const { app } = buildApp();
    const res = await app.request('/events', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        ...validPublicVenueBody(),
        venue: {
          address: '18 Raffles Quay',
          city: 'Singapore',
          latitude: 1.2806,
          longitude: 103.8504,
          category: 'apartment', // private category
        },
      }),
    });

    expect(res.status).toBe(422);
    const body = (await res.json()) as {
      error: { code: string; message: string; details: { subcode: string; reason: string } };
    };
    expect(body.error.code).toBe('UNPROCESSABLE');
    expect(body.error.details.subcode).toBe('FIRST_EVENT_MUST_BE_PUBLIC');
    expect(body.error.details.reason).toBe('category_not_public');
  });

  // ---- Case 2: POST first-time host + public category → 201 + venue.category in response ----

  it('POST /events — public category for first-time host returns 201 with venue.category', async () => {
    const { app } = buildApp();
    const res = await app.request('/events', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(validPublicVenueBody()),
    });

    expect(res.status).toBe(201);
    const body = (await res.json()) as {
      id: string;
      venue: { address: string; city: string; category: string };
    };
    expect(body.venue.category).toBe('cafe');
    expect(body.id).toBeTruthy();

    // Clean up the created event (user cascade would handle it, but explicit cleanup
    // avoids cross-test pollution for PATCH / GET cases within the same run).
    await db.event.delete({ where: { id: body.id } }).catch(() => null);
  });

  // ---- Case 3: POST first-time host + public category + keyword in address → 422 ----

  it('POST /events — private keyword in address returns 422 (keyword_match)', async () => {
    const { app } = buildApp();
    const res = await app.request('/events', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        ...validPublicVenueBody(),
        venue: {
          // "Marina Bay Apartments" — "apartment" keyword match → private
          address: 'Marina Bay Apartments',
          city: 'Singapore',
          latitude: 1.2806,
          longitude: 103.8504,
          category: 'park', // public category, but keyword match overrides
        },
      }),
    });

    expect(res.status).toBe(422);
    const body = (await res.json()) as {
      error: { code: string; details: { subcode: string; reason: string } };
    };
    expect(body.error.code).toBe('UNPROCESSABLE');
    expect(body.error.details.subcode).toBe('FIRST_EVENT_MUST_BE_PUBLIC');
    expect(body.error.details.reason).toBe('keyword_match');
  });

  // ---- Cases 4 & 5: Need a pre-existing event — create one first ----

  describe('with a pre-existing published event', () => {
    let eventId: string;

    beforeAll(async () => {
      if (!dbUrl) return;
      const { app } = buildApp();
      // Create a valid public event so PATCH tests have something to edit.
      // The GET test also reads this event.
      const res = await app.request('/events', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ...validPublicVenueBody(),
          title: 'PATCH & GET test event',
          venue: {
            address: '18 Raffles Quay',
            city: 'Singapore',
            latitude: 1.2806,
            longitude: 103.8504,
            category: 'hawker_centre',
          },
        }),
      });
      const body = (await res.json()) as { id: string };
      eventId = body.id;
    });

    afterAll(async () => {
      if (!dbUrl) return;
      await db.event.delete({ where: { id: eventId } }).catch(() => null);
    });

    // ---- Case 4: PATCH venue to private + first-time host → 422 ----

    it('PATCH /events/:id — patching venue to private category returns 422', async () => {
      const { app } = buildApp();
      const res = await app.request(`/events/${eventId}`, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          venue: {
            address: '1 Orchard Road',
            city: 'Singapore',
            latitude: 1.3,
            longitude: 103.85,
            category: 'condo', // private category
          },
        }),
      });

      expect(res.status).toBe(422);
      const body = (await res.json()) as {
        error: { code: string; details: { subcode: string } };
      };
      expect(body.error.code).toBe('UNPROCESSABLE');
      expect(body.error.details.subcode).toBe('FIRST_EVENT_MUST_BE_PUBLIC');
    });

    // ---- Case 5: GET /events/:id returns venue.category ----

    it('GET /events/:id returns event.venue.category', async () => {
      const { app } = buildApp();
      const res = await app.request(`/events/${eventId}`);

      expect(res.status).toBe(200);
      const body = (await res.json()) as {
        event: { id: string; venue: { category: string } };
      };
      expect(body.event.venue.category).toBe('hawker_centre');
    });
  });
});

/**
 * Verification gate tests for POST /events (TRI-16 SWE-FIX-C).
 *
 * Gate ordering contract: auth → verifiedEmail → verifiedPhone → rate-limit → validate → handler
 *
 * Cases:
 *   1. emailVerifiedAt=null → 403 EMAIL_NOT_VERIFIED (email gate fires first)
 *   2. emailVerifiedAt set, phoneVerifiedAt=null → 403 PHONE_NOT_VERIFIED
 */
describe.skipIf(!dbUrl)(
  'POST /events — requireVerifiedEmail + requireVerifiedPhone gates (TRI-16)',
  () => {
    let db: PrismaClient;

    // email NOT verified, phone NOT verified
    let unverifiedEmailUserId: string;
    let unverifiedEmailToken: string;

    // email verified, phone NOT verified
    let emailOnlyUserId: string;
    let emailOnlyToken: string;

    beforeAll(async () => {
      if (!dbUrl) return;
      db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
      const tokens = new JwtAccessTokenIssuer();

      unverifiedEmailUserId = createId();
      emailOnlyUserId = createId();

      await db.user.createMany({
        data: [
          {
            id: unverifiedEmailUserId,
            email: `unverified-email-${unverifiedEmailUserId}@event-gate.test`,
            displayName: 'Unverified Email User',
            emailVerifiedAt: null,
            phone: null,
            phoneVerifiedAt: null,
          },
          {
            id: emailOnlyUserId,
            email: `email-only-${emailOnlyUserId}@event-gate.test`,
            displayName: 'Email Only User',
            emailVerifiedAt: new Date(),
            phone: null,
            phoneVerifiedAt: null,
          },
        ],
      });

      unverifiedEmailToken = (
        await tokens.issue({
          userId: unverifiedEmailUserId,
          email: `unverified-email-${unverifiedEmailUserId}@event-gate.test`,
        })
      ).value;
      emailOnlyToken = (
        await tokens.issue({
          userId: emailOnlyUserId,
          email: `email-only-${emailOnlyUserId}@event-gate.test`,
        })
      ).value;
    });

    afterAll(async () => {
      if (!dbUrl) return;
      await db.user
        .deleteMany({ where: { id: { in: [unverifiedEmailUserId, emailOnlyUserId] } } })
        .catch(() => null);
      await db.$disconnect();
    });

    it('POST /events with emailVerifiedAt=null returns 403 EMAIL_NOT_VERIFIED', async () => {
      const { app } = buildApp();
      const res = await app.request('/events', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${unverifiedEmailToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(validPostBody()),
      });

      expect(res.status).toBe(403);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe('EMAIL_NOT_VERIFIED');
    });

    it('POST /events with email verified but phoneVerifiedAt=null returns 403 PHONE_NOT_VERIFIED', async () => {
      const { app } = buildApp();
      const res = await app.request('/events', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${emailOnlyToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(validPostBody()),
      });

      expect(res.status).toBe(403);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe('PHONE_NOT_VERIFIED');
    });
  },
);
