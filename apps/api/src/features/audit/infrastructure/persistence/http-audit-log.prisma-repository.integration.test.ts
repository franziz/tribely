// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { sha256Hex } from '@/core/crypto/sha256-hex.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';

import type { HttpAuditLogRecord } from '../../domain/repositories/http-audit-log.repository.js';
import { HttpAuditLogPrismaRepository } from './http-audit-log.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * Integration tests for HttpAuditLogPrismaRepository.
 *
 * Tests cover the `record` baseline and the `hashActorForUser` PDPA cascade
 * method added in TRI-134 Brief D. Each test tracks its own IDs for cleanup.
 */
describe.skipIf(!dbUrl)('HttpAuditLogPrismaRepository (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let repo: HttpAuditLogPrismaRepository;

  /**
   * `http_audit_logs` has a @@unique on `requestId`, so each record needs a
   * unique requestId. We track `id`s for cleanup.
   */
  const trackedIds = new Set<string>();

  const buildRecord = (
    overrides: Partial<HttpAuditLogRecord> = {},
  ): HttpAuditLogRecord => {
    const id = createId();
    trackedIds.add(id);
    return {
      id,
      requestId: createId(), // unique per row — @@unique constraint
      method: 'GET',
      path: '/test',
      status: 200,
      durationMs: 42,
      actorUserId: null,
      ip: '127.0.0.1',
      userAgent: 'test-agent/1.0',
      errorCode: null,
      receivedAt: new Date('2026-05-19T10:00:00Z'),
      ...overrides,
    };
  };

  beforeAll(() => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    repo = new HttpAuditLogPrismaRepository(db);
  });

  beforeEach(async () => {
    if (!dbUrl) return;
    if (trackedIds.size > 0) {
      await db.httpAuditLog.deleteMany({ where: { id: { in: [...trackedIds] } } });
      trackedIds.clear();
    }
  });

  afterAll(async () => {
    if (!dbUrl) return;
    if (trackedIds.size > 0) {
      await db.httpAuditLog
        .deleteMany({ where: { id: { in: [...trackedIds] } } })
        .catch(() => null);
    }
    await db.$disconnect();
  });

  it('record: inserts a row and the fields round-trip correctly', async () => {
    const actorId = createId();
    const entry = buildRecord({ actorUserId: actorId });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.httpAuditLog.findUnique({ where: { id: entry.id } });
    expect(row).not.toBeNull();
    expect(row?.id).toBe(entry.id);
    expect(row?.requestId).toBe(entry.requestId);
    expect(row?.method).toBe('GET');
    expect(row?.path).toBe('/test');
    expect(row?.status).toBe(200);
    expect(row?.actorUserId).toBe(actorId);
  });

  describe('hashActorForUser', () => {
    it('replaces actorUserId for the target user and returns updated count', async () => {
      const userX = createId();
      const userY = createId();
      const userZ = createId();
      const hashX = sha256Hex(userX);

      // Seed 3 rows — two for X, one for Y, one for Z.
      const rowX1 = buildRecord({ actorUserId: userX });
      const rowX2 = buildRecord({ actorUserId: userX });
      const rowY = buildRecord({ actorUserId: userY });
      const rowZ = buildRecord({ actorUserId: userZ });

      await unitOfWork.run(async (ctx) => {
        await repo.record(rowX1, ctx);
        await repo.record(rowX2, ctx);
        await repo.record(rowY, ctx);
        await repo.record(rowZ, ctx);
      });

      // Hash only user X.
      const count = await unitOfWork.run((ctx) =>
        repo.hashActorForUser(userX, hashX, ctx),
      );

      expect(count).toBe(2);

      // X's rows now carry the hash.
      const x1 = await db.httpAuditLog.findUnique({ where: { id: rowX1.id } });
      const x2 = await db.httpAuditLog.findUnique({ where: { id: rowX2.id } });
      expect(x1?.actorUserId).toBe(hashX);
      expect(x2?.actorUserId).toBe(hashX);

      // Y and Z are untouched.
      const y = await db.httpAuditLog.findUnique({ where: { id: rowY.id } });
      const z = await db.httpAuditLog.findUnique({ where: { id: rowZ.id } });
      expect(y?.actorUserId).toBe(userY);
      expect(z?.actorUserId).toBe(userZ);
    });

    it('returns 0 when no rows match userId', async () => {
      const unknownUser = createId();
      const count = await unitOfWork.run((ctx) =>
        repo.hashActorForUser(unknownUser, sha256Hex(unknownUser), ctx),
      );
      expect(count).toBe(0);
    });

    it('is idempotent: re-hashing an already-hashed row leaves it unchanged', async () => {
      const userId = createId();
      const hashV = sha256Hex(userId);

      // First pass: hash the plaintext userId.
      const rowA = buildRecord({ actorUserId: userId });
      await unitOfWork.run((ctx) => repo.record(rowA, ctx));

      await unitOfWork.run((ctx) => repo.hashActorForUser(userId, hashV, ctx));

      const afterFirstPass = await db.httpAuditLog.findUnique({ where: { id: rowA.id } });
      expect(afterFirstPass?.actorUserId).toBe(hashV);

      // Second pass: calling again on the same userId matches nothing (the
      // row now holds hashV, not userId), so count = 0 and value unchanged.
      const secondCount = await unitOfWork.run((ctx) =>
        repo.hashActorForUser(userId, hashV, ctx),
      );
      expect(secondCount).toBe(0);

      const afterSecondPass = await db.httpAuditLog.findUnique({ where: { id: rowA.id } });
      expect(afterSecondPass?.actorUserId).toBe(hashV);
    });

    it('leaves null actorUserId rows untouched', async () => {
      const userId = createId();
      const rowNull = buildRecord({ actorUserId: null });
      await unitOfWork.run((ctx) => repo.record(rowNull, ctx));

      const count = await unitOfWork.run((ctx) =>
        repo.hashActorForUser(userId, sha256Hex(userId), ctx),
      );
      expect(count).toBe(0);

      const row = await db.httpAuditLog.findUnique({ where: { id: rowNull.id } });
      expect(row?.actorUserId).toBeNull();
    });
  });
});
