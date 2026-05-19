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
 * HTTP-level integration tests for the `requireVerifiedPhone` gate on
 * join-request routes (SWE-8, TRI-16).
 *
 * Gate ordering contract (email fires first, then phone):
 *   requireAuth → requireVerifiedEmail → requireVerifiedPhone → handler
 *
 * Covers three gated route families:
 *   - POST /events/:id/join-requests  (event-scoped-join-request.routes.ts)
 *   - GET  /me/join-requests          (my-join-request.routes.ts)
 *   - POST /join-requests/:id/approve (join-request.routes.ts)
 *
 * Per-route cases:
 *   1. Unverified phone (email verified)           → 403 PHONE_NOT_VERIFIED
 *   2. Unverified email AND unverified phone       → 403 EMAIL_NOT_VERIFIED
 *      (asserts email gate fires before phone gate)
 */
describe.skipIf(!dbUrl)('Join-request routes — requireVerifiedPhone gate (TRI-16 SWE-8)', () => {
  let db: PrismaClient;

  let hostUserId: string;
  let eventId: string;

  // email-verified, phone-NOT-verified
  let emailOnlyUserId: string;
  let emailOnlyToken: string;

  // neither email nor phone verified
  let unverifiedUserId: string;
  let unverifiedToken: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    hostUserId = createId();
    emailOnlyUserId = createId();
    unverifiedUserId = createId();

    await db.user.createMany({
      data: [
        {
          id: hostUserId,
          email: `host-${hostUserId}@jr-phone-gate.test`,
          displayName: 'Host',
        },
        {
          id: emailOnlyUserId,
          email: `email-only-${emailOnlyUserId}@jr-phone-gate.test`,
          displayName: 'Email Only',
          emailVerifiedAt: new Date(),
          phone: null,
          phoneVerifiedAt: null,
        },
        {
          id: unverifiedUserId,
          email: `unverified-${unverifiedUserId}@jr-phone-gate.test`,
          displayName: 'Unverified',
          emailVerifiedAt: null,
          phone: null,
          phoneVerifiedAt: null,
        },
      ],
    });

    emailOnlyToken = (
      await tokens.issue({
        userId: emailOnlyUserId,
        email: `email-only-${emailOnlyUserId}@jr-phone-gate.test`,
      })
    ).value;
    unverifiedToken = (
      await tokens.issue({
        userId: unverifiedUserId,
        email: `unverified-${unverifiedUserId}@jr-phone-gate.test`,
      })
    ).value;

    const now = new Date();
    eventId = createId();
    await db.event.create({
      data: {
        id: eventId,
        hostUserId,
        title: 'Phone Gate Test Event',
        description: null,
        venueAddress: '1 Raffles Quay, Singapore',
        venueCity: 'Singapore',
        venueLatitude: 1.2848,
        venueLongitude: 103.8509,
        venueCategory: 'cafe',
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
    await db.event.deleteMany({ where: { id: eventId } }).catch(() => null);
    await db.user
      .deleteMany({ where: { id: { in: [hostUserId, emailOnlyUserId, unverifiedUserId] } } })
      .catch(() => null);
    await db.$disconnect();
  });

  // ── POST /events/:id/join-requests ──────────────────────────────────────

  describe('POST /events/:id/join-requests', () => {
    it('returns 403 PHONE_NOT_VERIFIED for email-verified but phone-unverified user', async () => {
      const { app } = buildApp();
      const res = await app.request(`/events/${eventId}/join-requests`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${emailOnlyToken}`,
          'Content-Type': 'application/json',
        },
      });
      expect(res.status).toBe(403);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe('PHONE_NOT_VERIFIED');
    });

    it('returns 403 EMAIL_NOT_VERIFIED for user with neither email nor phone verified (email gate fires first)', async () => {
      const { app } = buildApp();
      const res = await app.request(`/events/${eventId}/join-requests`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${unverifiedToken}`,
          'Content-Type': 'application/json',
        },
      });
      expect(res.status).toBe(403);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe('EMAIL_NOT_VERIFIED');
    });
  });

  // ── GET /me/join-requests ───────────────────────────────────────────────

  describe('GET /me/join-requests', () => {
    it('returns 403 PHONE_NOT_VERIFIED for email-verified but phone-unverified user', async () => {
      const { app } = buildApp();
      const res = await app.request('/me/join-requests', {
        headers: { Authorization: `Bearer ${emailOnlyToken}` },
      });
      expect(res.status).toBe(403);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe('PHONE_NOT_VERIFIED');
    });

    it('returns 403 EMAIL_NOT_VERIFIED for user with neither email nor phone verified (email gate fires first)', async () => {
      const { app } = buildApp();
      const res = await app.request('/me/join-requests', {
        headers: { Authorization: `Bearer ${unverifiedToken}` },
      });
      expect(res.status).toBe(403);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe('EMAIL_NOT_VERIFIED');
    });
  });

  // ── POST /join-requests/:id/approve ────────────────────────────────────
  //
  // We use a non-existent join-request ID. The phone gate runs before the
  // controller, so the 403 must come from the gate — not a 404 from a
  // missing row. This verifies the gate is in the middleware chain.

  describe('POST /join-requests/:id/approve', () => {
    const nonExistentJrId = createId();

    it('returns 403 PHONE_NOT_VERIFIED for email-verified but phone-unverified user', async () => {
      const { app } = buildApp();
      const res = await app.request(`/join-requests/${nonExistentJrId}/approve`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${emailOnlyToken}` },
      });
      expect(res.status).toBe(403);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe('PHONE_NOT_VERIFIED');
    });

    it('returns 403 EMAIL_NOT_VERIFIED for user with neither email nor phone verified (email gate fires first)', async () => {
      const { app } = buildApp();
      const res = await app.request(`/join-requests/${nonExistentJrId}/approve`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${unverifiedToken}` },
      });
      expect(res.status).toBe(403);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe('EMAIL_NOT_VERIFIED');
    });
  });
});
