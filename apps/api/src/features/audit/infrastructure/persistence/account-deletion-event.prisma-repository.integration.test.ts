// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { runWithContext } from '@/core/context/request-context.js';
import { sha256Hex } from '@/core/crypto/sha256-hex.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';

import type { AccountDeletionEventRecord } from '../../domain/repositories/account-deletion-event.repository.js';
import { AccountDeletionEventPrismaRepository } from './account-deletion-event.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * End-to-end repository test against the Postgres service container (CI) or
 * the local Neon dev branch (`.env`). Skipped when DATABASE_URL is unset so
 * unit-only runs still pass.
 *
 * The suite operates directly on `account_deletion_events`. No FK to User
 * exists (PDPA s24 requirement — rows must outlive the user record), so no
 * seed user is needed. Each test tracks its own IDs for cleanup.
 */
describe.skipIf(!dbUrl)('AccountDeletionEventPrismaRepository (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let repo: AccountDeletionEventPrismaRepository;
  const trackedIds = new Set<string>();

  const buildRecord = (
    overrides: Partial<AccountDeletionEventRecord> = {},
  ): AccountDeletionEventRecord => {
    const id = createId();
    trackedIds.add(id);
    return {
      id,
      userIdHash: sha256Hex(`user_${createId()}`),
      requestedAt: new Date('2026-05-19T10:00:00Z'),
      completedAt: new Date('2026-05-19T10:00:01Z'),
      requestId: 'req-integration-test',
      cascadeScope: ['users', 'credentials', 'refresh_tokens'],
      outcome: 'completed',
      failureReason: null,
      recordedAt: new Date('2026-05-19T10:00:02Z'),
      ...overrides,
    };
  };

  beforeAll(() => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    repo = new AccountDeletionEventPrismaRepository(db);
  });

  beforeEach(async () => {
    if (!dbUrl) return;
    if (trackedIds.size > 0) {
      await db.accountDeletionEvent.deleteMany({ where: { id: { in: [...trackedIds] } } });
      trackedIds.clear();
    }
  });

  afterAll(async () => {
    if (!dbUrl) return;
    if (trackedIds.size > 0) {
      await db.accountDeletionEvent
        .deleteMany({ where: { id: { in: [...trackedIds] } } })
        .catch(() => null);
    }
    await db.$disconnect();
  });

  it('record: inserts a row and the fields round-trip correctly', async () => {
    const entry = buildRecord({ requestId: 'req-roundtrip' });

    await runWithContext({ requestId: 'req-roundtrip', actorUserId: null }, () =>
      unitOfWork.run((ctx) => repo.record(entry, ctx)),
    );

    const row = await db.accountDeletionEvent.findUnique({ where: { id: entry.id } });
    expect(row).not.toBeNull();
    expect(row?.id).toBe(entry.id);
    expect(row?.userIdHash).toBe(entry.userIdHash);
    // SHA-256 hex is always 64 chars
    expect(row?.userIdHash).toMatch(/^[0-9a-f]{64}$/);
    expect(row?.requestedAt.toISOString()).toBe(entry.requestedAt.toISOString());
    expect(row?.completedAt.toISOString()).toBe(entry.completedAt.toISOString());
    expect(row?.requestId).toBe('req-roundtrip');
    expect(row?.cascadeScope).toEqual(['users', 'credentials', 'refresh_tokens']);
    expect(row?.outcome).toBe('completed');
    expect(row?.failureReason).toBeNull();
  });

  it('record: persists null requestId for non-HTTP origins', async () => {
    const entry = buildRecord({ requestId: null });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.accountDeletionEvent.findUnique({ where: { id: entry.id } });
    expect(row?.requestId).toBeNull();
  });

  it('record: persists failed_rolled_back outcome with failureReason', async () => {
    const entry = buildRecord({
      outcome: 'failed_rolled_back',
      failureReason: 'constraint violation on events table',
    });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.accountDeletionEvent.findUnique({ where: { id: entry.id } });
    expect(row?.outcome).toBe('failed_rolled_back');
    expect(row?.failureReason).toBe('constraint violation on events table');
  });

  it('record: persists full cascadeScope array', async () => {
    // 11 values — event_audit_logs_actor_hashed removed (Brief E adjudication):
    // EventAuditLog has no actorUserId column; HTTP-audit hashing covers all actor PII.
    const fullScope = [
      'users',
      'credentials',
      'refresh_tokens',
      'email_verification_tokens',
      'password_reset_tokens',
      'selfies',
      'check_ins',
      'events_hosted',
      'join_requests_authored',
      'http_audit_logs_actor_hashed',
      'outbox_events_redacted',
    ] as const;
    const entry = buildRecord({ cascadeScope: [...fullScope] });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.accountDeletionEvent.findUnique({ where: { id: entry.id } });
    expect(row?.cascadeScope).toEqual([...fullScope]);
  });

  it('is append-only: no UPDATE method exposed on repository', () => {
    // The AccountDeletionEventRepository interface exposes only `record`.
    // This test verifies the Prisma adapter does not accidentally expose mutation.
    expect(typeof repo.record).toBe('function');
    // @ts-expect-error — intentionally checking that update doesn't exist
    expect(typeof repo.update).toBe('undefined');
    // @ts-expect-error
    expect(typeof repo.pruneOlderThan).toBe('undefined');
  });
});
