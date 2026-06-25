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
 * HTTP-level integration test for the `requireVerifiedSelfie` gate on
 * `POST /events` (TRI-23 Brief C).
 *
 * Gate ordering contract (email → phone → selfie):
 *   requireAuth → requireVerifiedEmail → requireVerifiedPhone → requireVerifiedSelfie → handler
 *
 * Cases:
 *   1. Phone-verified but selfie-unverified (selfieStatus null) → 403 SELFIE_NOT_VERIFIED
 *   2. Phone-verified, selfie pending → 403 SELFIE_NOT_VERIFIED
 *   3. Phone-verified but no email verification → 403 EMAIL_NOT_VERIFIED (email gate fires first)
 *   4. Fully verified (email + phone + selfie approved) → not 403 SELFIE_NOT_VERIFIED
 *      (the create body may fail validation, but the gate itself passes — response code ≠ 403)
 */
describe.skipIf(!dbUrl)('POST /events — requireVerifiedSelfie gate (TRI-23 Brief C)', () => {
  let db: PrismaClient;

  // email + phone verified, selfieStatus = 'none'
  let noSelfieUserId: string;
  let noSelfieToken: string;
  let noSelfiePhone: string;

  // email + phone verified, selfieStatus = 'pending'
  let pendingSelfieUserId: string;
  let pendingSelfieToken: string;
  let pendingSelfiePhone: string;

  // email NOT verified, phone NOT verified (email gate fires before selfie gate)
  let unverifiedUserId: string;
  let unverifiedToken: string;

  // fully verified: email + phone + selfieStatus = 'approved'
  let approvedSelfieUserId: string;
  let approvedSelfieToken: string;
  let approvedSelfiePhone: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    noSelfieUserId = createId();
    pendingSelfieUserId = createId();
    unverifiedUserId = createId();
    approvedSelfieUserId = createId();

    // Derive unique E.164 Singapore numbers from timestamp suffix to avoid UNIQUE collisions.
    const ts = Date.now();
    noSelfiePhone = `+65${String(ts).slice(-8)}`;
    pendingSelfiePhone = `+65${String(ts + 1).slice(-8)}`;
    approvedSelfiePhone = `+65${String(ts + 2).slice(-8)}`;

    await db.user.createMany({
      data: [
        {
          id: noSelfieUserId,
          email: `no-selfie-${noSelfieUserId}@selfie-gate.test`,
          displayName: 'No Selfie',
          emailVerifiedAt: new Date(),
          phone: noSelfiePhone,
          phoneVerifiedAt: new Date(),
          // selfieStatus omitted → null (no selfie submitted yet)
        },
        {
          id: pendingSelfieUserId,
          email: `pending-selfie-${pendingSelfieUserId}@selfie-gate.test`,
          displayName: 'Pending Selfie',
          emailVerifiedAt: new Date(),
          phone: pendingSelfiePhone,
          phoneVerifiedAt: new Date(),
          selfieStatus: 'pending',
        },
        {
          id: unverifiedUserId,
          email: `unverified-${unverifiedUserId}@selfie-gate.test`,
          displayName: 'Unverified',
          emailVerifiedAt: null,
          phone: null,
          phoneVerifiedAt: null,
          // selfieStatus omitted → null
        },
        {
          id: approvedSelfieUserId,
          email: `approved-selfie-${approvedSelfieUserId}@selfie-gate.test`,
          displayName: 'Approved Selfie',
          emailVerifiedAt: new Date(),
          phone: approvedSelfiePhone,
          phoneVerifiedAt: new Date(),
          selfieStatus: 'approved',
        },
      ],
    });

    noSelfieToken = (
      await tokens.issue({
        userId: noSelfieUserId,
        email: `no-selfie-${noSelfieUserId}@selfie-gate.test`,
      })
    ).value;
    pendingSelfieToken = (
      await tokens.issue({
        userId: pendingSelfieUserId,
        email: `pending-selfie-${pendingSelfieUserId}@selfie-gate.test`,
      })
    ).value;
    unverifiedToken = (
      await tokens.issue({
        userId: unverifiedUserId,
        email: `unverified-${unverifiedUserId}@selfie-gate.test`,
      })
    ).value;
    approvedSelfieToken = (
      await tokens.issue({
        userId: approvedSelfieUserId,
        email: `approved-selfie-${approvedSelfieUserId}@selfie-gate.test`,
      })
    ).value;
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.user
      .deleteMany({
        where: {
          id: {
            in: [noSelfieUserId, pendingSelfieUserId, unverifiedUserId, approvedSelfieUserId],
          },
        },
      })
      .catch(() => null);
    await db.$disconnect();
  });

  it('returns 403 SELFIE_NOT_VERIFIED for phone-verified user with selfieStatus=null (no selfie submitted)', async () => {
    const { app } = buildApp();
    const res = await app.request('/events', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${noSelfieToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(403);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('SELFIE_NOT_VERIFIED');
  });

  it('returns 403 SELFIE_NOT_VERIFIED for phone-verified user with selfieStatus=pending', async () => {
    const { app } = buildApp();
    const res = await app.request('/events', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${pendingSelfieToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(403);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('SELFIE_NOT_VERIFIED');
  });

  it('returns 403 EMAIL_NOT_VERIFIED for fully unverified user (email gate fires before selfie gate)', async () => {
    const { app } = buildApp();
    const res = await app.request('/events', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${unverifiedToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(403);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('EMAIL_NOT_VERIFIED');
  });

  it('does not return 403 SELFIE_NOT_VERIFIED for fully verified user (selfieStatus=approved)', async () => {
    const { app } = buildApp();
    const res = await app.request('/events', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${approvedSelfieToken}`,
        'Content-Type': 'application/json',
      },
      // Intentionally invalid body — the selfie gate passes and validation rejects.
      body: JSON.stringify({}),
    });
    // Gate passed — the handler or validation layer returns something other than 403 SELFIE_NOT_VERIFIED.
    if (res.status === 403) {
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).not.toBe('SELFIE_NOT_VERIFIED');
    } else {
      // 400 (validation error on empty body) or any other non-403-selfie is acceptable.
      expect(res.status).not.toBe(200);
    }
  });
});
