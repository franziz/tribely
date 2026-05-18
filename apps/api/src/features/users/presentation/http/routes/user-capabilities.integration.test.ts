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
 * HTTP-level integration test for GET /users/me/capabilities.
 *
 * Exercises: JWT auth middleware → route → controller → use case →
 * StubHostRatingsReadModel (returns null) + EventPrismaRepository → DB.
 *
 * Cases:
 *   - 401 without Authorization header.
 *   - 200 with { canPostPrivateVenue: false } for a fresh user (no events,
 *     stub ratings → null → capability permanently false at MVP launch).
 *   - Route-ordering guard: GET /users/me/capabilities must NOT be swallowed
 *     by the /:id wildcard handler (which validates cuid format and would
 *     400 or 404 on "me").
 */
describe.skipIf(!dbUrl)('GET /users/me/capabilities (integration)', () => {
  let db: PrismaClient;
  let userId: string;
  let token: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    userId = createId();
    const email = `capabilities-${userId}@test.local`;

    await db.user.create({
      data: {
        id: userId,
        email,
        displayName: 'Cap Test User',
        emailVerifiedAt: new Date(),
      },
    });

    const issued = await tokens.issue({ userId, email });
    token = issued.value;
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.user.delete({ where: { id: userId } }).catch(() => null);
    await db.$disconnect();
  });

  it('returns 401 when no Authorization header is supplied', async () => {
    const { app } = buildApp();
    const res = await app.request('/users/me/capabilities');
    expect(res.status).toBe(401);
  });

  it('returns 200 with canPostPrivateVenue: false for a fresh user (no completed events)', async () => {
    const { app } = buildApp();
    const res = await app.request('/users/me/capabilities', {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { canPostPrivateVenue: boolean };
    expect(body.canPostPrivateVenue).toBe(false);
  });

  it('does NOT route GET /users/me/capabilities into the /:id wildcard handler', async () => {
    // If route order were wrong, /:id would receive id="me", which may
    // fail format validation (cuid check) → 400, or fail a DB lookup → 404.
    // This test asserts neither: the response must be exactly 200 or 401
    // (i.e., the /me/capabilities handler took it), never 400 or 404.
    const { app } = buildApp();

    // Unauthenticated — capabilities handler returns 401, /:id handler would
    // 404 (user "me" doesn't exist in DB). Both 401 here confirm correct routing.
    const unauthedRes = await app.request('/users/me/capabilities');
    expect(unauthedRes.status).toBe(401);

    // Authenticated — capabilities handler returns 200, /:id handler would
    // either 400 (cuid format fail) or 404 (no user with id "me").
    const authedRes = await app.request('/users/me/capabilities', {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(authedRes.status).toBe(200);
    // Confirm we got the capabilities shape, not a user profile or error body.
    const body = await authedRes.json();
    expect(body).toHaveProperty('canPostPrivateVenue');
    expect(typeof (body as Record<string, unknown>).canPostPrivateVenue).toBe('boolean');
  });
});
