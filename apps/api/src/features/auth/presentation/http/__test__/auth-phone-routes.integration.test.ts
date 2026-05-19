// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { requestContext } from '@/core/middleware/request-context.js';
import { errorHandler } from '@/core/middleware/error-handler.js';
import { InMemoryRateLimiter } from '@/core/security/in-memory-rate-limiter.js';
import type { PhoneVerifier } from '@/core/sms/phone-verifier.port.js';
import type {
  StartVerificationResult,
  CheckVerificationResult,
} from '@/core/sms/phone-verifier.port.js';
import { JwtAccessTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-access-token-issuer.js';
import { SystemClock } from '@/features/auth/infrastructure/adapters/system-clock.js';
import { StartPhoneVerificationUseCase } from '@/features/auth/application/usecases/start-phone-verification.usecase.js';
import { VerifyPhoneUseCase } from '@/features/auth/application/usecases/verify-phone.usecase.js';
import { UserPrismaRepository } from '@/features/users/infrastructure/persistence/user.prisma-repository.js';
import { Sha256PhoneHasher } from '@/core/sms/sha256-phone-hasher.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import { OutboxEventPublisher } from '@/core/events/index.js';
import { buildAuthRoutes } from '../routes/auth.routes.js';
import { buildApp } from '../../../../../app.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const dbUrl = process.env.DATABASE_URL;

/**
 * Build a minimal Hono app with only the /auth routes, using the provided
 * phoneVerifier. Used to test error branches that LoggingPhoneVerifier never
 * reaches (rate_limited, etc.).
 */
const buildPhoneAuthApp = (db: PrismaClient, phoneVerifier: PhoneVerifier) => {
  const rateLimiter = new InMemoryRateLimiter();
  const userRepository = new UserPrismaRepository(db);
  const phoneHasher = new Sha256PhoneHasher('test-phone-hash-salt-32chars-00000');
  const unitOfWork = new PrismaUnitOfWork(db);
  const publisher = new OutboxEventPublisher();
  const clock = new SystemClock();
  const accessTokens = new JwtAccessTokenIssuer();

  const startPhoneVerification = new StartPhoneVerificationUseCase({
    users: userRepository,
    phoneVerifier,
    events: publisher,
    unitOfWork,
    clock,
  });
  const verifyPhone = new VerifyPhoneUseCase({
    users: userRepository,
    phoneVerifier,
    phoneHasher,
    events: publisher,
    unitOfWork,
    clock,
  });

  const app = new Hono();
  app.use('*', cors());
  app.use('*', requestContext());
  app.route(
    '/auth',
    buildAuthRoutes({
      // Stub remaining deps that are not exercised by phone routes.
      // Use type-cast to avoid full wiring — only phone paths are tested here.
      signUp: null as never,
      signIn: null as never,
      refresh: null as never,
      signOut: null as never,
      signOutAll: null as never,
      getUser: null as never,
      verifyEmail: null as never,
      resendVerification: null as never,
      requestPasswordReset: null as never,
      resetPassword: null as never,
      startPhoneVerification,
      verifyPhone,
      accessTokens,
      rateLimiter,
    }),
  );
  app.onError(errorHandler);
  return app;
};

// ---------------------------------------------------------------------------
// Controllable fake verifier
// ---------------------------------------------------------------------------

/**
 * A PhoneVerifier fake that allows per-call result injection via queues.
 * Used to exercise rate_limited and other non-happy-path branches.
 */
class QueuedPhoneVerifier implements PhoneVerifier {
  private readonly startQueue: StartVerificationResult[] = [];
  private readonly checkQueue: CheckVerificationResult[] = [];

  enqueueStart(...results: StartVerificationResult[]): void {
    this.startQueue.push(...results);
  }

  enqueueCheck(...results: CheckVerificationResult[]): void {
    this.checkQueue.push(...results);
  }

  startVerification(): Promise<StartVerificationResult> {
    const next = this.startQueue.shift();
    if (!next) throw new Error('QueuedPhoneVerifier.startVerification queue empty');
    return Promise.resolve(next);
  }

  checkVerification(): Promise<CheckVerificationResult> {
    const next = this.checkQueue.shift();
    if (!next) throw new Error('QueuedPhoneVerifier.checkVerification queue empty');
    return Promise.resolve(next);
  }
}

// ---------------------------------------------------------------------------
// Test suites
// ---------------------------------------------------------------------------

describe.skipIf(!dbUrl)('POST /auth/phone/start (integration)', () => {
  let db: PrismaClient;
  let userId: string;
  let token: string;

  const VALID_SG_PHONE = '+6591234567';

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    userId = createId();
    const email = `phone-start-${userId}@test.local`;
    await db.user.create({
      data: { id: userId, email, displayName: 'Phone Start Test User' },
    });

    const issued = await tokens.issue({ userId, email });
    token = issued.value;
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.user.delete({ where: { id: userId } }).catch(() => null);
    await db.$disconnect();
  });

  it('200 happy path — valid phone, authenticated', async () => {
    const { app } = buildApp();
    const res = await app.request('/auth/phone/start', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ phone: VALID_SG_PHONE }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean };
    expect(body.ok).toBe(true);
  });

  it('401 — unauthenticated request is rejected', async () => {
    const { app } = buildApp();
    const res = await app.request('/auth/phone/start', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: VALID_SG_PHONE }),
    });

    expect(res.status).toBe(401);
  });

  it('400 — invalid E.164 phone number', async () => {
    const { app } = buildApp();
    const res = await app.request('/auth/phone/start', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ phone: 'not-a-phone' }),
    });

    // zValidator accepts the string (length pass) and PhoneNumber.create throws
    // AppError.validation which maps to 400.
    expect(res.status).toBe(400);
  });

  it('429 — 4th call within hour for same phone is rate-limited', async () => {
    const { app } = buildApp();
    const makeRequest = () =>
      app.request('/auth/phone/start', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ phone: VALID_SG_PHONE }),
      });

    // phone-start limit is 3/hour per phone. First three succeed.
    for (let i = 0; i < 3; i++) {
      const res = await makeRequest();
      expect(res.status).toBe(200);
    }

    // Fourth call hits the bucket ceiling.
    const res = await makeRequest();
    expect(res.status).toBe(429);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('VALIDATION_ERROR');
  });

  it('422 — Twilio rate-limit (sms_rate_limited subcode)', async () => {
    const fakeVerifier = new QueuedPhoneVerifier();
    fakeVerifier.enqueueStart({ status: 'rate_limited' });
    const app = buildPhoneAuthApp(db, fakeVerifier);

    const tokens = new JwtAccessTokenIssuer();
    const localUserId = createId();
    const localEmail = `phone-start-twilio-rl-${localUserId}@test.local`;
    await db.user.create({ data: { id: localUserId, email: localEmail, displayName: 'RL User' } });
    const { value: localToken } = await tokens.issue({ userId: localUserId, email: localEmail });

    const res = await app.request('/auth/phone/start', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${localToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ phone: VALID_SG_PHONE }),
    });

    await db.user.delete({ where: { id: localUserId } }).catch(() => null);

    expect(res.status).toBe(422);
    const body = (await res.json()) as { error: { code: string; details: { subcode: string } } };
    expect(body.error.code).toBe('UNPROCESSABLE');
    expect(body.error.details.subcode).toBe('sms_rate_limited');
  });

  it('malformed JSON body passes through to zValidator — not a 500', async () => {
    const { app } = buildApp();
    const res = await app.request('/auth/phone/start', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: 'not-json{{{',
    });

    // zValidator catches the malformed body and returns 400, not 500.
    // This verifies the middleware does not throw on parse failure.
    expect(res.status).not.toBe(500);
    expect(res.status).toBe(400);
  });
});

describe.skipIf(!dbUrl)('POST /auth/phone/verify (integration)', () => {
  let db: PrismaClient;
  let userId: string;
  let token: string;

  const VALID_SG_PHONE = '+6591234568';
  const DEV_MAGIC_CODE = '000000';
  const WRONG_CODE = '999999';

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    userId = createId();
    const email = `phone-verify-${userId}@test.local`;
    await db.user.create({
      data: { id: userId, email, displayName: 'Phone Verify Test User' },
    });

    const issued = await tokens.issue({ userId, email });
    token = issued.value;
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.user.delete({ where: { id: userId } }).catch(() => null);
    await db.$disconnect();
  });

  it('200 — valid phone + magic code verifies successfully', async () => {
    const { app } = buildApp();
    const res = await app.request('/auth/phone/verify', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ phone: VALID_SG_PHONE, code: DEV_MAGIC_CODE }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { id: string; phoneVerifiedAt: string | null };
    // verifyPhoneAction returns toAuthUserDto(user) — the user object directly
    expect(body).toHaveProperty('id');
  });

  it('200 — idempotent re-verify returns 200', async () => {
    const { app } = buildApp();
    // Second verify call — user already has phoneVerifiedAt set from prior test.
    const res = await app.request('/auth/phone/verify', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ phone: VALID_SG_PHONE, code: DEV_MAGIC_CODE }),
    });

    expect(res.status).toBe(200);
  });

  it('400 — wrong code returns 400 VALIDATION_ERROR', async () => {
    // Use a different phone so it hasn't been verified yet (avoids idempotent guard).
    const freshUserId = createId();
    const freshEmail = `phone-verify-wrong-${freshUserId}@test.local`;
    const tokens = new JwtAccessTokenIssuer();
    await db.user.create({
      data: { id: freshUserId, email: freshEmail, displayName: 'Wrong Code User' },
    });
    const { value: freshToken } = await tokens.issue({
      userId: freshUserId,
      email: freshEmail,
    });

    const { app } = buildApp();
    const res = await app.request('/auth/phone/verify', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${freshToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ phone: '+6591234569', code: WRONG_CODE }),
    });

    await db.user.delete({ where: { id: freshUserId } }).catch(() => null);

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('VALIDATION_ERROR');
  });

  it('401 — unauthenticated request is rejected', async () => {
    const { app } = buildApp();
    const res = await app.request('/auth/phone/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: VALID_SG_PHONE, code: DEV_MAGIC_CODE }),
    });

    expect(res.status).toBe(401);
  });

  it('429 — 6th attempt within hour for same phone is rate-limited', async () => {
    // Use a distinct phone to avoid bucket contamination from other tests.
    const rateLimitPhone = '+6591234570';
    const freshUserId = createId();
    const freshEmail = `phone-verify-rl-${freshUserId}@test.local`;
    const tokens = new JwtAccessTokenIssuer();
    await db.user.create({
      data: { id: freshUserId, email: freshEmail, displayName: 'RL Verify User' },
    });
    const { value: freshToken } = await tokens.issue({
      userId: freshUserId,
      email: freshEmail,
    });

    // Build a single app instance to share the in-memory rate limiter.
    const { app } = buildApp();
    const makeRequest = () =>
      app.request('/auth/phone/verify', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${freshToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ phone: rateLimitPhone, code: WRONG_CODE }),
      });

    // phone-verify limit is 5/hour per phone. First 5 fail with 400 (wrong code).
    for (let i = 0; i < 5; i++) {
      const res = await makeRequest();
      // First verify also succeeds on 200 with magic code but we use wrong code
      // so they return 400 — rate limit counter still increments.
      expect(res.status).toBe(400);
    }

    // 6th call hits the bucket ceiling — rate limiter runs BEFORE use case.
    const res = await makeRequest();
    expect(res.status).toBe(429);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('VALIDATION_ERROR');

    await db.user.delete({ where: { id: freshUserId } }).catch(() => null);
  });
});
