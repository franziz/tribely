// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { runWithContext } from '@/core/context/request-context.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';

import type { ModerationActionAuditRecord } from '../../domain/repositories/moderation-action-audit.repository.js';
import { ModerationActionAuditPrismaRepository } from './moderation-action-audit.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * End-to-end repository test against the Postgres service container (CI) or
 * the local Neon dev branch (`.env`). Skipped when DATABASE_URL is unset so
 * unit-only runs still pass.
 *
 * The suite operates directly on `moderation_action_audit`. No FK to Report,
 * User, or Review exists — audit rows must outlive any referenced records
 * (PDPA s24 evidence-integrity requirement). Each test tracks its own IDs
 * for cleanup.
 */
describe.skipIf(!dbUrl)('ModerationActionAuditPrismaRepository (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let repo: ModerationActionAuditPrismaRepository;
  const trackedIds = new Set<string>();

  const buildRecord = (
    overrides: Partial<ModerationActionAuditRecord> = {},
  ): ModerationActionAuditRecord => {
    const id = createId();
    trackedIds.add(id);
    return {
      id,
      operatorUserId: createId(),
      action: 'touch',
      reportId: createId(),
      targetType: 'review',
      targetId: createId(),
      reason: null,
      contentSnapshot: null,
      reporterUserId: createId(),
      reasonCode: null,
      justificationText: null,
      originatingReportId: null,
      actedAt: new Date('2026-05-24T10:00:00Z'),
      requestId: 'system:cli.moderation.touch:test',
      recordedAt: new Date('2026-05-24T10:00:01Z'),
      ...overrides,
    };
  };

  beforeAll(() => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    repo = new ModerationActionAuditPrismaRepository(db);
  });

  beforeEach(async () => {
    if (!dbUrl) return;
    if (trackedIds.size > 0) {
      await db.moderationActionAudit.deleteMany({ where: { id: { in: [...trackedIds] } } });
      trackedIds.clear();
    }
  });

  afterAll(async () => {
    if (!dbUrl) return;
    if (trackedIds.size > 0) {
      await db.moderationActionAudit
        .deleteMany({ where: { id: { in: [...trackedIds] } } })
        .catch(() => null);
    }
    await db.$disconnect();
  });

  it('record: inserts a row and the fields round-trip correctly', async () => {
    const entry = buildRecord({
      action: 'resolve_hidden',
      targetType: 'review',
      reason: 'contains hate speech',
      contentSnapshot: 'This is the verbatim review text captured at action time.',
      requestId: 'system:cli.moderation.resolve:req-roundtrip',
    });

    await runWithContext(
      { requestId: 'system:cli.moderation.resolve:req-roundtrip', actorUserId: null },
      () => unitOfWork.run((ctx) => repo.record(entry, ctx)),
    );

    const row = await db.moderationActionAudit.findUnique({ where: { id: entry.id } });
    expect(row).not.toBeNull();
    expect(row?.id).toBe(entry.id);
    expect(row?.operatorUserId).toBe(entry.operatorUserId);
    expect(row?.action).toBe('resolve_hidden');
    expect(row?.reportId).toBe(entry.reportId);
    expect(row?.targetType).toBe('review');
    expect(row?.targetId).toBe(entry.targetId);
    expect(row?.reason).toBe('contains hate speech');
    expect(row?.contentSnapshot).toBe('This is the verbatim review text captured at action time.');
    expect(row?.reporterUserId).toBe(entry.reporterUserId);
    expect(row?.actedAt.toISOString()).toBe(entry.actedAt.toISOString());
    expect(row?.requestId).toBe('system:cli.moderation.resolve:req-roundtrip');
    expect(row?.recordedAt).not.toBeNull();
  });

  it('record: persists null requestId for non-HTTP origins', async () => {
    const entry = buildRecord({ requestId: null });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.moderationActionAudit.findUnique({ where: { id: entry.id } });
    expect(row?.requestId).toBeNull();
  });

  it('record: persists null reason and contentSnapshot for touch action', async () => {
    const entry = buildRecord({ action: 'touch', reason: null, contentSnapshot: null });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.moderationActionAudit.findUnique({ where: { id: entry.id } });
    expect(row?.action).toBe('touch');
    expect(row?.reason).toBeNull();
    expect(row?.contentSnapshot).toBeNull();
  });

  it('record: persists resolve_kept with reason and null contentSnapshot', async () => {
    const entry = buildRecord({
      action: 'resolve_kept',
      reason: 'content does not violate community guidelines',
      contentSnapshot: null,
    });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.moderationActionAudit.findUnique({ where: { id: entry.id } });
    expect(row?.action).toBe('resolve_kept');
    expect(row?.reason).toBe('content does not violate community guidelines');
    expect(row?.contentSnapshot).toBeNull();
  });

  it('record: CHECK constraint rejects invalid action value', async () => {
    const entry = buildRecord();
    // Override id not tracked — this row will never be inserted
    const invalidEntry = { ...entry, id: createId(), action: 'ban_user' as never };

    await expect(unitOfWork.run((ctx) => repo.record(invalidEntry, ctx))).rejects.toThrow();
  });

  it('record: CHECK constraint rejects invalid targetType value', async () => {
    const entry = buildRecord();
    const invalidEntry = { ...entry, id: createId(), targetType: 'comment' as never };

    await expect(unitOfWork.run((ctx) => repo.record(invalidEntry, ctx))).rejects.toThrow();
  });

  it('is append-only: no UPDATE method exposed on repository', () => {
    expect(typeof repo.record).toBe('function');
    // @ts-expect-error — intentionally checking that update doesn't exist
    expect(typeof repo.update).toBe('undefined');
    // @ts-expect-error — intentionally checking that pruneOlderThan doesn't exist
    expect(typeof repo.pruneOlderThan).toBe('undefined');
    // @ts-expect-error — intentionally checking that delete doesn't exist
    expect(typeof repo.delete).toBe('undefined');
  });
});
