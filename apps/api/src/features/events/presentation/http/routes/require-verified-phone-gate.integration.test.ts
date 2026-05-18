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
 * HTTP-level integration test for the `requireVerifiedPhone` gate on
 * `GET /me/events` (SWE-8, TRI-16).
 *
 * Gate ordering contract (email fires first, then phone):
 *   requireAuth → requireVerifiedEmail → requireVerifiedPhone → handler
 *
 * Cases:
 *   1. Unverified phone (email verified) → 403 PHONE_NOT_VERIFIED
 *   2. Unverified email AND unverified phone → 403 EMAIL_NOT_VERIFIED (email gate fires first)
 *   3. Fully verified (email + phone) → 200 (happy path, gate passes)
 */
describe.skipIf(!dbUrl)('GET /me/events — requireVerifiedPhone gate (TRI-16 SWE-8)', () => {
  let db: PrismaClient;

  // email-verified, phone-NOT-verified
  let emailOnlyUserId: string;
  let emailOnlyToken: string;

  // neither email nor phone verified
  let unverifiedUserId: string;
  let unverifiedToken: string;

  // email + phone verified — happy path
  let fullyVerifiedUserId: string;
  let fullyVerifiedToken: string;

  // Unique E.164 phone for the fully-verified fixture.
  // The phone column has a UNIQUE constraint AND is validated as E.164 on read-back
  // (UserMapper throws if the stored value isn't valid E.164). We use a
  // timestamp-derived suffix so parallel test runs don't collide.
  // Singapore (+65) numbers are +65 + 8 digits.
  let fullyVerifiedPhone: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    emailOnlyUserId = createId();
    unverifiedUserId = createId();
    fullyVerifiedUserId = createId();

    // Derive a unique E.164 number from the last 8 digits of a timestamp.
    // UNIQUE constraint on `phone` + E.164 validation on mapper read-back.
    const ts8 = String(Date.now()).slice(-8);
    fullyVerifiedPhone = `+65${ts8}`;

    await db.user.createMany({
      data: [
        {
          id: emailOnlyUserId,
          email: `email-only-${emailOnlyUserId}@me-events-phone-gate.test`,
          displayName: 'Email Only',
          emailVerifiedAt: new Date(),
          phone: null,
          phoneVerifiedAt: null,
        },
        {
          id: unverifiedUserId,
          email: `unverified-${unverifiedUserId}@me-events-phone-gate.test`,
          displayName: 'Unverified',
          emailVerifiedAt: null,
          phone: null,
          phoneVerifiedAt: null,
        },
        {
          id: fullyVerifiedUserId,
          email: `fully-verified-${fullyVerifiedUserId}@me-events-phone-gate.test`,
          displayName: 'Fully Verified',
          emailVerifiedAt: new Date(),
          phone: fullyVerifiedPhone,
          phoneVerifiedAt: new Date(),
        },
      ],
    });

    emailOnlyToken = (
      await tokens.issue({
        userId: emailOnlyUserId,
        email: `email-only-${emailOnlyUserId}@me-events-phone-gate.test`,
      })
    ).value;
    unverifiedToken = (
      await tokens.issue({
        userId: unverifiedUserId,
        email: `unverified-${unverifiedUserId}@me-events-phone-gate.test`,
      })
    ).value;
    fullyVerifiedToken = (
      await tokens.issue({
        userId: fullyVerifiedUserId,
        email: `fully-verified-${fullyVerifiedUserId}@me-events-phone-gate.test`,
      })
    ).value;
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.user
      .deleteMany({
        where: { id: { in: [emailOnlyUserId, unverifiedUserId, fullyVerifiedUserId] } },
      })
      .catch(() => null);
    await db.$disconnect();
  });

  it('returns 403 PHONE_NOT_VERIFIED for email-verified but phone-unverified user', async () => {
    const { app } = buildApp();
    const res = await app.request('/me/events', {
      headers: { Authorization: `Bearer ${emailOnlyToken}` },
    });
    expect(res.status).toBe(403);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('PHONE_NOT_VERIFIED');
  });

  it('returns 403 EMAIL_NOT_VERIFIED for user with neither email nor phone verified (email gate fires first)', async () => {
    const { app } = buildApp();
    const res = await app.request('/me/events', {
      headers: { Authorization: `Bearer ${unverifiedToken}` },
    });
    expect(res.status).toBe(403);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('EMAIL_NOT_VERIFIED');
  });

  it('returns 200 for fully verified user (email + phone)', async () => {
    const { app } = buildApp();
    const res = await app.request('/me/events', {
      headers: { Authorization: `Bearer ${fullyVerifiedToken}` },
    });
    expect(res.status).toBe(200);
  });
});
