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
 * Integration test: admin middleware three-way auth matrix on
 * POST /admin/users/:id/selfie/reject.
 *
 * Covers TRI-132 Brief C acceptance criteria:
 *   - AC #2: unauthed → 401 UNAUTHORIZED
 *   - AC #2: authed non-admin → 403 FORBIDDEN
 *   - AC #2: authed admin → middleware passes (status is not 401/403)
 *   - AC #6: 401/403 response bodies carry no PII (no userId, email, or user
 *            attribute in the error envelope)
 */
describe.skipIf(!dbUrl)(
  'POST /admin/users/:id/selfie/reject — admin middleware matrix (integration)',
  () => {
    let db: PrismaClient;
    let tokens: JwtAccessTokenIssuer;

    let nonAdminUserId: string;
    let nonAdminEmail: string;
    let nonAdminToken: string;

    let adminUserId: string;
    let adminEmail: string;
    let adminToken: string;

    // A stable target user id for the path param — the route handler will
    // fail with a domain error for a missing/non-pending selfie, but the
    // middleware layer (401/403) fires before that, so the target need not
    // have a real pending selfie for the 401/403 cases.
    let targetUserId: string;

    beforeAll(async () => {
      if (!dbUrl) return;
      db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
      tokens = new JwtAccessTokenIssuer();

      // ── 1. Non-admin user ─────────────────────────────────────────────────
      nonAdminUserId = createId();
      nonAdminEmail = `admin-mw-nonadmin-${nonAdminUserId}@test.local`;
      await db.user.create({
        data: {
          id: nonAdminUserId,
          email: nonAdminEmail,
          displayName: 'NonAdmin User',
          emailVerifiedAt: new Date(),
          isAdmin: false,
        },
      });
      const nonAdminIssued = await tokens.issue({
        userId: nonAdminUserId,
        email: nonAdminEmail,
      });
      nonAdminToken = nonAdminIssued.value;

      // ── 2. Admin user ─────────────────────────────────────────────────────
      adminUserId = createId();
      adminEmail = `admin-mw-admin-${adminUserId}@test.local`;
      await db.user.create({
        data: {
          id: adminUserId,
          email: adminEmail,
          displayName: 'Admin User',
          emailVerifiedAt: new Date(),
          isAdmin: true,
        },
      });
      const adminIssued = await tokens.issue({ userId: adminUserId, email: adminEmail });
      adminToken = adminIssued.value;

      // ── 3. Target user (path param) ───────────────────────────────────────
      // Does not need to be an admin or have a pending selfie. For the
      // admin-passthrough test we only assert "not 401/403"; any downstream
      // domain error (e.g. selfie not found) is acceptable.
      targetUserId = createId();
      await db.user.create({
        data: {
          id: targetUserId,
          email: `admin-mw-target-${targetUserId}@test.local`,
          displayName: 'Target User',
        },
      });
    });

    afterAll(async () => {
      if (!dbUrl) return;
      await db.user
        .deleteMany({
          where: { id: { in: [nonAdminUserId, adminUserId, targetUserId].filter(Boolean) } },
        })
        .catch(() => null);
      await db.$disconnect();
    });

    // ── Test 1: no Authorization header → 401 ──────────────────────────────

    it('returns 401 UNAUTHORIZED when no Authorization header is provided', async () => {
      const { app } = buildApp();
      const res = await app.request(`/admin/users/${targetUserId}/selfie/reject`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ failureCategory: 'blur' }),
      });
      expect(res.status).toBe(401);
      const body = (await res.json()) as Record<string, unknown>;
      const error = body['error'] as Record<string, unknown>;
      expect(error['code']).toBe('UNAUTHORIZED');
    });

    // ── Test 2: valid token, non-admin → 403 ──────────────────────────────

    it('returns 403 FORBIDDEN when authenticated user is not an admin', async () => {
      const { app } = buildApp();
      const res = await app.request(`/admin/users/${targetUserId}/selfie/reject`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${nonAdminToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ failureCategory: 'blur' }),
      });
      expect(res.status).toBe(403);
      const body = (await res.json()) as Record<string, unknown>;
      const error = body['error'] as Record<string, unknown>;
      expect(error['code']).toBe('FORBIDDEN');
    });

    // ── Test 3: valid token, admin → middleware passes ─────────────────────

    it('passes the middleware chain when authenticated user is an admin (status is not 401/403)', async () => {
      const { app } = buildApp();
      const res = await app.request(`/admin/users/${targetUserId}/selfie/reject`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ failureCategory: 'blur' }),
      });
      // The middleware chain passed. The use case may return a domain error
      // (e.g. no pending selfie for targetUserId) — that's fine. What matters
      // is the response is NOT a middleware-level 401 or 403.
      expect(res.status).not.toBe(401);
      expect(res.status).not.toBe(403);
    });

    // ── Test 4: PII regression — 403 body must not contain user attributes ─

    it('403 response body contains no PII (no userId, email, or user attributes)', async () => {
      const { app } = buildApp();
      const res = await app.request(`/admin/users/${targetUserId}/selfie/reject`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${nonAdminToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ failureCategory: 'blur' }),
      });
      expect(res.status).toBe(403);
      const body = (await res.json()) as Record<string, unknown>;
      const bodyString = JSON.stringify(body);

      // Must not leak the path param, the actor's userId, or the actor's email.
      expect(bodyString).not.toContain(targetUserId);
      expect(bodyString).not.toContain(nonAdminUserId);
      expect(bodyString).not.toContain(nonAdminEmail);

      // Error envelope shape: { error: { code, message } } — no 'details' field
      // carrying user attributes.
      const error = body['error'] as Record<string, unknown>;
      expect(error['code']).toBe('FORBIDDEN');
      expect(typeof error['message']).toBe('string');
      // details may be undefined or null; must not carry user data
      if (error['details'] !== undefined && error['details'] !== null) {
        expect(JSON.stringify(error['details'])).not.toContain(nonAdminEmail);
        expect(JSON.stringify(error['details'])).not.toContain(nonAdminUserId);
      }
    });
  },
);
