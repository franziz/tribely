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
 * HTTP-level integration test for the `isVerified` field on GET /users/:id.
 *
 * AC4 anchor: even an email-verified user returns `isVerified: false` under
 * the default signal set `['email','phone','selfie']` because `phoneVerifiedAt`
 * and `selfieApprovedAt` are hardcoded to null until TRI-16 / TRI-23 ship.
 *
 * Cases:
 *   1. User with emailVerifiedAt null → isVerified: false, field present.
 *   2. User with emailVerifiedAt set → isVerified: false (AC4 anchor).
 *   3. Field is always present and always boolean in both cases.
 */
describe.skipIf(!dbUrl)('GET /users/:id — isVerified field (integration)', () => {
  let db: PrismaClient;
  let tokens: JwtAccessTokenIssuer;

  let unverifiedUserId: string;
  let unverifiedToken: string;

  let emailVerifiedUserId: string;
  let emailVerifiedToken: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    tokens = new JwtAccessTokenIssuer();

    // Seed 1: user with no email verification
    unverifiedUserId = createId();
    const unverifiedEmail = `isverified-unverified-${unverifiedUserId}@test.local`;
    await db.user.create({
      data: {
        id: unverifiedUserId,
        email: unverifiedEmail,
        displayName: 'Unverified User',
        emailVerifiedAt: null,
      },
    });
    const issuedUnverified = await tokens.issue({
      userId: unverifiedUserId,
      email: unverifiedEmail,
    });
    unverifiedToken = issuedUnverified.value;

    // Seed 2: user with email verified
    emailVerifiedUserId = createId();
    const emailVerifiedEmail = `isverified-emailverified-${emailVerifiedUserId}@test.local`;
    await db.user.create({
      data: {
        id: emailVerifiedUserId,
        email: emailVerifiedEmail,
        displayName: 'Email Verified User',
        emailVerifiedAt: new Date(),
      },
    });
    const issuedEmailVerified = await tokens.issue({
      userId: emailVerifiedUserId,
      email: emailVerifiedEmail,
    });
    emailVerifiedToken = issuedEmailVerified.value;
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.user.delete({ where: { id: unverifiedUserId } }).catch(() => null);
    await db.user.delete({ where: { id: emailVerifiedUserId } }).catch(() => null);
    await db.$disconnect();
  });

  it('returns isVerified: false for a user with emailVerifiedAt null', async () => {
    const { app } = buildApp();
    const res = await app.request(`/users/${unverifiedUserId}`, {
      headers: { Authorization: `Bearer ${unverifiedToken}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.isVerified).toBe(false);
    expect(typeof body.isVerified).toBe('boolean');
  });

  it('returns isVerified: false even when emailVerifiedAt is set (AC4 anchor: phone+selfie signals null)', async () => {
    const { app } = buildApp();
    const res = await app.request(`/users/${emailVerifiedUserId}`, {
      headers: { Authorization: `Bearer ${emailVerifiedToken}` },
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    // AC4: until TRI-16 (phone) and TRI-23 (selfie) ship, phoneVerifiedAt and
    // selfieApprovedAt are hardcoded null in GetUserUseCase — so even an
    // email-verified user does not pass all three signals.
    expect(body.isVerified).toBe(false);
    expect(typeof body.isVerified).toBe('boolean');
  });

  it('isVerified field is always present and boolean in both seeded cases', async () => {
    const { app } = buildApp();

    const res1 = await app.request(`/users/${unverifiedUserId}`, {
      headers: { Authorization: `Bearer ${unverifiedToken}` },
    });
    const body1 = (await res1.json()) as Record<string, unknown>;
    expect('isVerified' in body1).toBe(true);
    expect(typeof body1.isVerified).toBe('boolean');

    const res2 = await app.request(`/users/${emailVerifiedUserId}`, {
      headers: { Authorization: `Bearer ${emailVerifiedToken}` },
    });
    const body2 = (await res2.json()) as Record<string, unknown>;
    expect('isVerified' in body2).toBe(true);
    expect(typeof body2.isVerified).toBe('boolean');
  });
});
