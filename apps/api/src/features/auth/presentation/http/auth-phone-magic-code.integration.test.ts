// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { JwtAccessTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-access-token-issuer.js';
import { buildApp } from '../../../../app.js';

/**
 * Regression test: SMS_TRANSPORT=log magic code "000000" accepted end-to-end.
 *
 * Root cause (TRI-126): AutofillHints.oneTimeCode on OtpCodeInput was injecting
 * a real device SMS OTP, overwriting the user's "000000" keystrokes on real
 * devices. The server path was provably clean; this test locks the full HTTP
 * path — start → verify with magic code → phoneVerifiedAt set — against any
 * future server-side regression.
 *
 * Precondition: SMS_TRANSPORT=log (the dev default). The buildApp() factory
 * loads env.ts which wires LoggingPhoneVerifier when SMS_TRANSPORT=log.
 */
describe.skipIf(!process.env.DATABASE_URL)(
  'POST /auth/phone/verify — magic code 000000 on SMS_TRANSPORT=log',
  () => {
    let db: PrismaClient;
    let userId: string;
    let token: string;

    const PHONE = '+6591230001';
    const MAGIC_CODE = '000000';

    beforeAll(async () => {
      const dbUrl = process.env.DATABASE_URL;
      if (!dbUrl) return;

      db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
      const tokens = new JwtAccessTokenIssuer();

      userId = createId();
      const email = `magic-code-${userId}@test.local`;
      await db.user.create({
        data: { id: userId, email, displayName: 'Magic Code Test User' },
      });

      const issued = await tokens.issue({ userId, email });
      token = issued.value;
    });

    afterAll(async () => {
      await db.user.delete({ where: { id: userId } }).catch(() => null);
      await db.$disconnect();
    });

    it('start + verify with 000000 returns 200 and flips phoneVerifiedAt to non-null', async () => {
      const { app } = buildApp();

      // Step 1: start phone verification — must succeed first.
      const startRes = await app.request('/auth/phone/start', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ phone: PHONE }),
      });
      expect(startRes.status).toBe(200);

      // Step 2: verify with magic code.
      const verifyRes = await app.request('/auth/phone/verify', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ phone: PHONE, code: MAGIC_CODE }),
      });
      expect(verifyRes.status).toBe(200);

      // Step 3: confirm phoneVerifiedAt was persisted — the HTTP DTO does not
      // surface phone fields, so query the DB directly.
      const persisted = await db.user.findUniqueOrThrow({ where: { id: userId } });
      expect(persisted.phoneVerifiedAt).not.toBeNull();
    });

    it('wrong code returns 400 — distinguishes magic-code-invalid from other errors', async () => {
      // Fresh user so the idempotent guard doesn't skip the verifier check.
      const freshUserId = createId();
      const freshEmail = `magic-wrong-${freshUserId}@test.local`;
      const freshPhone = '+6591230002';
      const tokens = new JwtAccessTokenIssuer();
      await db.user.create({
        data: { id: freshUserId, email: freshEmail, displayName: 'Wrong Code User' },
      });
      const { value: freshToken } = await tokens.issue({ userId: freshUserId, email: freshEmail });

      const { app } = buildApp();

      // Call start first so the test is robust to any future guard added to
      // the verifier that requires a prior start before check will resolve.
      const startRes = await app.request('/auth/phone/start', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${freshToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ phone: freshPhone }),
      });
      expect(startRes.status).toBe(200);

      const res = await app.request('/auth/phone/verify', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${freshToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ phone: freshPhone, code: '111111' }),
      });

      await db.user.delete({ where: { id: freshUserId } }).catch(() => null);

      expect(res.status).toBe(400);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });
  },
);
