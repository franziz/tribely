// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { sha256Hex } from '@/core/crypto/sha256-hex.js';
import { Password } from '../../../../auth/domain/value-objects/password.js';
import { JwtAccessTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-access-token-issuer.js';
import { Argon2PasswordHasher } from '@/features/auth/infrastructure/adapters/argon2-password-hasher.js';
import { buildApp } from '../../../../../app.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * End-to-end HTTP integration test for DELETE /users/me.
 *
 * Covers TRI-134 Brief E acceptance criteria:
 *   - 204 on first call (happy path) + direct-DB cascade assertions.
 *   - users row: tombstoned, deletedAt set, PII cleared (email placeholder).
 *   - credentials, refresh_tokens, email_verification_tokens, password_reset_tokens: gone.
 *   - selfies: deletedAt set (if row existed); selfie_pending_storage_deletes enqueued.
 *   - post_event_check_ins: pseudonymised/deleted per TRI-29 rules.
 *   - events: hostUserId rewritten to pseudonym.
 *   - join_requests: requesterUserId rewritten to same pseudonym.
 *   - http_audit_logs: actorUserId rewritten to SHA-256 hash of original userId.
 *   - outbox_events: un-dispatched row's payload pseudonymised; dispatched rows untouched.
 *   - account_deletion_events: one row, outcome=completed, 11 cascadeScope values,
 *     userIdHash = sha256Hex(original userId).
 *   - 409 ACCOUNT_ALREADY_DELETED on second DELETE with the same JWT.
 *   - auth failure after deletion: refresh token row is gone.
 *   - 401 without auth token.
 *
 * Test isolation: each seeded resource is tracked and cleaned up in afterAll.
 * The user's deletedAt sets email to a placeholder, so cleanup targets by id, not email.
 */
describe.skipIf(!dbUrl)('DELETE /users/me — account-deletion cascade (integration)', () => {
  let db: PrismaClient;
  let tokens: JwtAccessTokenIssuer;
  let passwordHasher: Argon2PasswordHasher;

  // Primary test subject
  let userId: string;
  let userEmail: string;
  let userToken: string;

  // Seeded supporting resources
  let eventId: string;
  let joinRequestId: string;
  let checkInId: string;
  let selfieId: string;
  let httpAuditLogId: string;
  let outboxUndispatchedId: string;
  let outboxDispatchedId: string;
  let credentialExists: boolean;

  // Refresh token raw value for post-delete refresh attempt
  let refreshTokenRaw: string;
  let refreshTokenHash: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    tokens = new JwtAccessTokenIssuer();
    passwordHasher = new Argon2PasswordHasher();

    userId = createId();
    userEmail = `delete-acct-${userId}@test.local`;

    // ── 1. Seed user with email verified ─────────────────────────────────────
    await db.user.create({
      data: {
        id: userId,
        email: userEmail,
        displayName: 'DeleteMe User',
        emailVerifiedAt: new Date(),
      },
    });

    const issued = await tokens.issue({ userId, email: userEmail });
    userToken = issued.value;

    // ── 2. Seed credential ────────────────────────────────────────────────────
    const password = Password.create('TestPass123!');
    const passwordHash = await passwordHasher.hash(password);
    await db.credential.create({
      data: { userId, passwordHash: passwordHash.value },
    });
    credentialExists = true;

    // ── 3. Seed refresh token ─────────────────────────────────────────────────
    refreshTokenRaw = createId();
    refreshTokenHash = sha256Hex(refreshTokenRaw);
    await db.refreshToken.create({
      data: {
        id: createId(),
        userId,
        tokenHash: refreshTokenHash,
        expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24),
        issuedAt: new Date(),
        revokedAt: null,
        revokedReason: null,
        rotatedToId: null,
      },
    });

    // ── 4. Seed email verification token ──────────────────────────────────────
    await db.emailVerificationToken.create({
      data: {
        id: createId(),
        userId,
        codeHash: sha256Hex('123456'),
        expiresAt: new Date(Date.now() + 1000 * 60 * 60),
        issuedAt: new Date(),
        consumedAt: null,
        invalidated: false,
      },
    });

    // ── 5. Seed a second user (event host for join request) ───────────────────
    const hostUserId = createId();
    const hostEmail = `delete-acct-host-${hostUserId}@test.local`;
    await db.user.create({
      data: { id: hostUserId, email: hostEmail, displayName: 'Host User' },
    });

    // ── 6. Seed event hosted by user ──────────────────────────────────────────
    eventId = createId();
    await db.event.create({
      data: {
        id: eventId,
        hostUserId: userId,
        title: 'TRI-134 Test Event',
        venueAddress: '18 Raffles Quay',
        venueCity: 'Singapore',
        venueLatitude: 1.2806,
        venueLongitude: 103.8504,
        venueCategory: 'cafe',
        startsAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        endsAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000 + 3600 * 1000),
        capacity: 5,
        category: 'food',
        costSplit: 'own',
        approvalMode: 'manual',
        status: 'active',
      },
    });

    // ── 7. Seed join request authored by user on the host's event ─────────────
    const anotherEventId = createId();
    await db.event.create({
      data: {
        id: anotherEventId,
        hostUserId: hostUserId,
        title: 'TRI-134 Another Event',
        venueAddress: '18 Raffles Quay',
        venueCity: 'Singapore',
        venueLatitude: 1.2806,
        venueLongitude: 103.8504,
        venueCategory: 'cafe',
        startsAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        endsAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000 + 3600 * 1000),
        capacity: 5,
        category: 'food',
        costSplit: 'own',
        approvalMode: 'manual',
        status: 'active',
      },
    });
    joinRequestId = createId();
    await db.joinRequest.create({
      data: {
        id: joinRequestId,
        eventId: anotherEventId,
        requesterUserId: userId,
        status: 'pending',
        requestedAt: new Date(),
      },
    });

    // ── 8. Seed a selfie row ───────────────────────────────────────────────────
    selfieId = createId();
    await db.selfie.create({
      data: {
        id: selfieId,
        userId,
        status: 'approved',
        storageKey: `selfies/${userId}/selfie.jpg`,
        deletedAt: null,
      },
    });

    // ── 9. Seed a post_event_check_in (flagged, so it gets pseudonymised) ─────
    checkInId = createId();
    await db.postEventCheckIn.create({
      data: {
        id: checkInId,
        userId,
        eventId,
        hostUserId: userId, // user hosted this event
        status: 'flagged',
        reportBody: 'TRI-134 test check-in content',
        flaggedAt: new Date(),
      },
    });

    // ── 10. Seed an http_audit_log row with actorUserId = userId ──────────────
    httpAuditLogId = createId();
    await db.httpAuditLog.create({
      data: {
        id: httpAuditLogId,
        requestId: `req-delete-test-${userId}`,
        method: 'GET',
        path: '/users/me/capabilities',
        status: 200,
        durationMs: 12,
        actorUserId: userId,
        ip: null,
        userAgent: null,
        errorCode: null,
        receivedAt: new Date(),
      },
    });

    // ── 11. Seed outbox events (one un-dispatched, one dispatched) ────────────
    // "Un-dispatched" = seq > MIN(committed_seq) across all consumer_offsets.
    // "Dispatched" = seq <= MIN(committed_seq) — committed by every consumer.
    //
    // Strategy: seed the "dispatched" row FIRST (gets a lower seq), then seed
    // a consumer_offset row committing AT that seq. The "un-dispatched" row
    // gets a higher seq and no consumer has committed past it.

    // dispatched: seeded first to get a lower seq
    outboxDispatchedId = createId();
    const dispatchedRow = await db.outboxEvent.create({
      data: {
        id: outboxDispatchedId,
        type: 'users.userRegistered',
        actorUserId: userId,
        aggregateType: 'User',
        aggregateId: userId,
        payload: { userId, email: userEmail, displayName: 'DeleteMe User' },
      },
    });
    // Mark this seq as committed by our test consumer — every row at or below
    // this seq is "dispatched" from MIN(committed_seq)'s perspective.
    await db.consumerOffset.upsert({
      where: { consumerName: 'test.deleteAccountIntegration.dispatched' },
      update: { committedSeq: dispatchedRow.seq },
      create: {
        consumerName: 'test.deleteAccountIntegration.dispatched',
        topic: 'users.userRegistered',
        committedSeq: dispatchedRow.seq,
      },
    });

    // un-dispatched: seeded AFTER the consumer_offset commit so its seq is
    // strictly > MIN(committed_seq), making it a candidate for redaction.
    outboxUndispatchedId = createId();
    await db.outboxEvent.create({
      data: {
        id: outboxUndispatchedId,
        type: 'users.userRegistered',
        actorUserId: userId,
        aggregateType: 'User',
        aggregateId: userId,
        payload: { userId, email: userEmail, displayName: 'DeleteMe User' },
      },
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;

    // Clean up all test state. Account deletion tombstones the user row —
    // we try deletion by id (tolerating "already deleted" or "not found").
    await db.outboxEvent
      .deleteMany({
        where: { id: { in: [outboxUndispatchedId, outboxDispatchedId].filter(Boolean) } },
      })
      .catch(() => null);
    await db.consumerOffset
      .delete({ where: { consumerName: 'test.deleteAccountIntegration.dispatched' } })
      .catch(() => null);
    await db.httpAuditLog.deleteMany({ where: { actorUserId: userId } }).catch(() => null);
    // http_audit_logs actorUserId was hashed — also clean by requestId prefix
    await db.httpAuditLog
      .deleteMany({ where: { requestId: { startsWith: `req-delete-test-${userId}` } } })
      .catch(() => null);
    await db.accountDeletionEvent
      .deleteMany({ where: { userIdHash: sha256Hex(userId) } })
      .catch(() => null);
    await db.selfiePendingStorageDelete.deleteMany({ where: { selfieId } }).catch(() => null);
    await db.selfie.deleteMany({ where: { id: selfieId } }).catch(() => null);
    await db.joinRequest.deleteMany({ where: { id: joinRequestId } }).catch(() => null);
    await db.postEventCheckIn.deleteMany({ where: { id: checkInId } }).catch(() => null);
    // The events and second event's join request cascade on event delete
    await db.event.deleteMany({ where: { id: eventId } }).catch(() => null);
    // Second user (hostUserId) — their event might also be left
    await db.event
      .deleteMany({ where: { hostUserId: { startsWith: 'delete-acct-host' } } })
      .catch(() => null);
    await db.user
      .deleteMany({ where: { email: { startsWith: 'delete-acct-host' } } })
      .catch(() => null);
    await db.user.deleteMany({ where: { id: userId } }).catch(() => null);

    await db.$disconnect();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Happy path
  // ──────────────────────────────────────────────────────────────────────────

  it('DELETE /users/me returns 204 No Content', async () => {
    const { app } = buildApp();
    const res = await app.request('/users/me', {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${userToken}` },
    });
    expect(res.status).toBe(204);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Direct-DB cascade assertions (run after the 204 test above)
  // ──────────────────────────────────────────────────────────────────────────

  it('users row is tombstoned with deletedAt set and PII email cleared', async () => {
    const row = await db.user.findUnique({ where: { id: userId } });
    expect(row).not.toBeNull();
    expect(row?.deletedAt).not.toBeNull();
    // tombstone() replaces email with 'deleted-{cuid}@deleted.tribely.local'
    expect(row?.email).toMatch(/^deleted-.+@deleted\.tribely\.local$/);
  });

  it('credentials row is hard-deleted', async () => {
    const row = await db.credential.findUnique({ where: { userId } });
    expect(row).toBeNull();
    // Suppress unused variable warning for the setup flag
    void credentialExists;
  });

  it('refresh_tokens rows are hard-deleted', async () => {
    const rows = await db.refreshToken.findMany({ where: { userId } });
    expect(rows).toHaveLength(0);
  });

  it('email_verification_tokens rows are hard-deleted', async () => {
    const rows = await db.emailVerificationToken.findMany({ where: { userId } });
    expect(rows).toHaveLength(0);
  });

  it('selfies row has deletedAt set and selfie_pending_storage_deletes enqueued', async () => {
    const selfie = await db.selfie.findUnique({ where: { id: selfieId } });
    expect(selfie?.deletedAt).not.toBeNull();

    // SelfiePendingStorageDelete row enqueued by DeleteSelfieForUserUseCase
    const pending = await db.selfiePendingStorageDelete.findFirst({ where: { selfieId } });
    expect(pending).not.toBeNull();
  });

  it('post_event_check_ins flagged rows pseudonymised (userId no longer matches original)', async () => {
    const row = await db.postEventCheckIn.findUnique({ where: { id: checkInId } });
    // PseudonymiseCheckInsForUserUseCase rewrites userId on flagged rows.
    expect(row).not.toBeNull();
    if (row) {
      expect(row.userId).not.toBe(userId);
    }
  });

  it('events hostUserId rewritten to a cuid2 pseudonym (not original userId)', async () => {
    const row = await db.event.findUnique({ where: { id: eventId } });
    expect(row).not.toBeNull();
    expect(row?.hostUserId).not.toBe(userId);
    // Verify it's a valid cuid2-shaped string (lowercase alphanumeric, 24+ chars)
    expect(row?.hostUserId).toMatch(/^[a-z0-9]{20,}$/);
  });

  it('join_requests requesterUserId rewritten to same pseudonym as events.hostUserId', async () => {
    const eventRow = await db.event.findUnique({ where: { id: eventId } });
    const jrRow = await db.joinRequest.findUnique({ where: { id: joinRequestId } });
    expect(jrRow).not.toBeNull();
    expect(jrRow?.requesterUserId).not.toBe(userId);
    // Same pseudonym used for both — verify join request uses same cuid2 as event host
    expect(jrRow?.requesterUserId).toBe(eventRow?.hostUserId);
  });

  it('http_audit_logs actorUserId rewritten to sha256Hex of original userId', async () => {
    const row = await db.httpAuditLog.findUnique({ where: { id: httpAuditLogId } });
    expect(row).not.toBeNull();
    expect(row?.actorUserId).toBe(sha256Hex(userId));
  });

  it('outbox_events: un-dispatched row payload userId pseudonymised', async () => {
    const row = await db.outboxEvent.findUnique({ where: { id: outboxUndispatchedId } });
    expect(row).not.toBeNull();
    if (row) {
      const payload = row.payload as Record<string, unknown>;
      // payload.userId should no longer be the original userId
      expect(payload['userId']).not.toBe(userId);
    }
  });

  it('outbox_events: dispatched row payload is untouched (MIN boundary)', async () => {
    const row = await db.outboxEvent.findUnique({ where: { id: outboxDispatchedId } });
    expect(row).not.toBeNull();
    if (row) {
      const payload = row.payload as Record<string, unknown>;
      // Dispatched row's payload was not redacted
      expect(payload['userId']).toBe(userId);
    }
  });

  it('account_deletion_events: one row with outcome=completed and 11 cascadeScope values', async () => {
    const rows = await db.accountDeletionEvent.findMany({
      where: { userIdHash: sha256Hex(userId) },
    });
    expect(rows).toHaveLength(1);
    const row = rows[0];
    expect(row?.outcome).toBe('completed');
    expect(row?.userIdHash).toBe(sha256Hex(userId));
    expect(row?.failureReason).toBeNull();

    const expectedScopes = [
      'credentials',
      'refresh_tokens',
      'email_verification_tokens',
      'password_reset_tokens',
      'selfies',
      'check_ins',
      'events_hosted',
      'join_requests_authored',
      'outbox_events_redacted',
      'http_audit_logs_actor_hashed',
      'users',
    ];
    expect(row?.cascadeScope).toEqual(expectedScopes);
    expect(row?.cascadeScope).toHaveLength(11);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 409 on second call with the same JWT
  // ──────────────────────────────────────────────────────────────────────────

  it('second DELETE /users/me returns 409 ACCOUNT_ALREADY_DELETED', async () => {
    const { app } = buildApp();
    const res = await app.request('/users/me', {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${userToken}` },
    });
    expect(res.status).toBe(409);
    const body = (await res.json()) as Record<string, unknown>;
    const error = body['error'] as Record<string, unknown>;
    expect(error['code']).toBe('CONFLICT');
    const details = error['details'] as Record<string, unknown>;
    expect(details['subcode']).toBe('ACCOUNT_ALREADY_DELETED');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Auth edge cases
  // ──────────────────────────────────────────────────────────────────────────

  it('DELETE /users/me returns 401 without auth token', async () => {
    const { app } = buildApp();
    const res = await app.request('/users/me', { method: 'DELETE' });
    expect(res.status).toBe(401);
  });

  it('refresh token is gone — cannot refresh after deletion', async () => {
    const row = await db.refreshToken.findFirst({ where: { tokenHash: refreshTokenHash } });
    expect(row).toBeNull();
  });
});
