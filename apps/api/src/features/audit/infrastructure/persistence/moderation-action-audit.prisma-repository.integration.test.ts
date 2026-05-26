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
      escalationCategory: null,
      externalRef: null,
      externalSource: null,
      externalDisposition: null,
      externalReceivedAt: null,
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

  it('record: persists escalate action with escalationCategory and externalRef', async () => {
    const entry = buildRecord({
      action: 'escalate',
      escalationCategory: 'criminal-content',
      externalRef: 'SGP-CASE-2026-001',
    });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.moderationActionAudit.findUnique({ where: { id: entry.id } });
    expect(row?.action).toBe('escalate');
    expect(row?.escalationCategory).toBe('criminal-content');
    expect(row?.externalRef).toBe('SGP-CASE-2026-001');
    expect(row?.externalSource).toBeNull();
    expect(row?.externalDisposition).toBeNull();
    expect(row?.externalReceivedAt).toBeNull();
  });

  it('record: persists record_external_input with externalSource, externalDisposition, and externalReceivedAt', async () => {
    const externalReceivedAt = new Date('2026-05-20T08:00:00Z');
    const entry = buildRecord({
      action: 'record_external_input',
      externalSource: 'imda',
      externalDisposition: 'No further action required.',
      externalReceivedAt,
      // actedAt is the CLI invocation clock — distinct from externalReceivedAt
      actedAt: new Date('2026-05-24T13:00:00Z'),
    });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.moderationActionAudit.findUnique({ where: { id: entry.id } });
    expect(row?.action).toBe('record_external_input');
    expect(row?.externalSource).toBe('imda');
    expect(row?.externalDisposition).toBe('No further action required.');
    expect(row?.externalReceivedAt?.toISOString()).toBe(externalReceivedAt.toISOString());
    // Confirm actedAt and externalReceivedAt are stored as separate distinct timestamps
    expect(row?.actedAt.toISOString()).toBe('2026-05-24T13:00:00.000Z');
    expect(row?.escalationCategory).toBeNull();
    expect(row?.externalRef).toBeNull();
  });

  it('record: persists resolve_with_override with escalationCategory carried forward', async () => {
    const entry = buildRecord({
      action: 'resolve_with_override',
      escalationCategory: 'imminent-harm',
    });

    await unitOfWork.run((ctx) => repo.record(entry, ctx));

    const row = await db.moderationActionAudit.findUnique({ where: { id: entry.id } });
    expect(row?.action).toBe('resolve_with_override');
    expect(row?.escalationCategory).toBe('imminent-harm');
    expect(row?.externalRef).toBeNull();
    expect(row?.externalSource).toBeNull();
    expect(row?.externalDisposition).toBeNull();
    expect(row?.externalReceivedAt).toBeNull();
  });

  it('record: CHECK constraint rejects invalid escalationCategory value', async () => {
    const entry = buildRecord({
      action: 'escalate',
      escalationCategory: 'not-a-valid-category' as never,
    });

    await expect(unitOfWork.run((ctx) => repo.record(entry, ctx))).rejects.toThrow();
  });

  it('record: CHECK constraint rejects invalid externalSource value', async () => {
    const entry = buildRecord({
      action: 'record_external_input',
      externalSource: 'invalid-source' as never,
    });

    await expect(unitOfWork.run((ctx) => repo.record(entry, ctx))).rejects.toThrow();
  });

  describe('countExternalInputs', () => {
    it('returns 0 when no record_external_input rows exist for the given reportId', async () => {
      const reportId = createId();

      const count = await repo.countExternalInputs(reportId);

      expect(count).toBe(0);
    });

    it('returns the exact count of record_external_input rows for the given reportId', async () => {
      const reportId = createId();
      const entries = [
        buildRecord({ reportId, action: 'record_external_input', externalSource: 'imda' }),
        buildRecord({ reportId, action: 'record_external_input', externalSource: 'counsel' }),
        buildRecord({ reportId, action: 'record_external_input', externalSource: 'partner' }),
      ];
      for (const e of entries) {
        await unitOfWork.run((ctx) => repo.record(e, ctx));
      }

      const count = await repo.countExternalInputs(reportId);

      expect(count).toBe(3);
    });

    it('does NOT count non-record_external_input actions for the same reportId', async () => {
      const reportId = createId();
      await unitOfWork.run((ctx) =>
        repo.record(
          buildRecord({ reportId, action: 'escalate', escalationCategory: 'imminent-harm' }),
          ctx,
        ),
      );
      await unitOfWork.run((ctx) =>
        repo.record(
          buildRecord({ reportId, action: 'record_external_input', externalSource: 'imda' }),
          ctx,
        ),
      );
      await unitOfWork.run((ctx) =>
        repo.record(
          buildRecord({
            reportId,
            action: 'resolve_with_override',
            escalationCategory: 'imminent-harm',
          }),
          ctx,
        ),
      );

      const count = await repo.countExternalInputs(reportId);

      expect(count).toBe(1);
    });

    it('does NOT count record_external_input rows for a different reportId', async () => {
      const reportId = createId();
      const otherReportId = createId();
      await unitOfWork.run((ctx) =>
        repo.record(
          buildRecord({
            reportId: otherReportId,
            action: 'record_external_input',
            externalSource: 'imda',
          }),
          ctx,
        ),
      );

      const count = await repo.countExternalInputs(reportId);

      expect(count).toBe(0);
    });

    it('accepts an optional TxContext and uses it when provided', async () => {
      const reportId = createId();
      await unitOfWork.run((ctx) =>
        repo.record(
          buildRecord({ reportId, action: 'record_external_input', externalSource: 'counsel' }),
          ctx,
        ),
      );

      const count = await unitOfWork.run((ctx) => repo.countExternalInputs(reportId, ctx));

      expect(count).toBe(1);
    });
  });

  describe('severOriginatingReportId', () => {
    it('returns 0 when no audit row references the given reportId', async () => {
      const unreferencedReportId = createId();

      const count = await unitOfWork.run((ctx) =>
        repo.severOriginatingReportId(unreferencedReportId, ctx),
      );

      expect(count).toBe(0);
    });

    it('returns 1, NULLs originatingReportId, and leaves all other fields unchanged when one audit row references the reportId', async () => {
      const reportId = createId();
      const entry = buildRecord({
        originatingReportId: reportId,
        action: 'resolve_hidden',
        reason: 'violates guidelines',
        contentSnapshot: 'verbatim content at action time',
        reasonCode: null,
        justificationText: null,
      });
      await runWithContext({ requestId: entry.requestId ?? 'system:test', actorUserId: null }, () =>
        unitOfWork.run((ctx) => repo.record(entry, ctx)),
      );

      const count = await unitOfWork.run((ctx) => repo.severOriginatingReportId(reportId, ctx));

      expect(count).toBe(1);

      const row = await db.moderationActionAudit.findUnique({ where: { id: entry.id } });
      expect(row).not.toBeNull();
      // originatingReportId severed
      expect(row?.originatingReportId).toBeNull();
      // All other evidence fields preserved (PDPA s24 / AC bullet 2)
      expect(row?.operatorUserId).toBe(entry.operatorUserId);
      expect(row?.action).toBe('resolve_hidden');
      expect(row?.targetType).toBe(entry.targetType);
      expect(row?.targetId).toBe(entry.targetId);
      expect(row?.reason).toBe('violates guidelines');
      expect(row?.contentSnapshot).toBe('verbatim content at action time');
      expect(row?.reporterUserId).toBe(entry.reporterUserId);
      expect(row?.reasonCode).toBeNull();
      expect(row?.justificationText).toBeNull();
      expect(row?.actedAt.toISOString()).toBe(entry.actedAt.toISOString());
      expect(row?.recordedAt).not.toBeNull();
    });

    it('returns N and severs all N rows when multiple audits reference the same reportId', async () => {
      const reportId = createId();
      const entries = [
        buildRecord({ originatingReportId: reportId }),
        buildRecord({ originatingReportId: reportId }),
        buildRecord({ originatingReportId: reportId }),
      ];
      for (const e of entries) {
        await unitOfWork.run((ctx) => repo.record(e, ctx));
      }

      const count = await unitOfWork.run((ctx) => repo.severOriginatingReportId(reportId, ctx));

      expect(count).toBe(3);

      for (const e of entries) {
        const row = await db.moderationActionAudit.findUnique({ where: { id: e.id } });
        expect(row?.originatingReportId).toBeNull();
      }
    });

    it('does NOT touch audit rows referencing a different reportId', async () => {
      const targetReportId = createId();
      const untouchedReportId = createId();

      const targetEntry = buildRecord({ originatingReportId: targetReportId });
      const untouchedEntry = buildRecord({ originatingReportId: untouchedReportId });
      await unitOfWork.run((ctx) => repo.record(targetEntry, ctx));
      await unitOfWork.run((ctx) => repo.record(untouchedEntry, ctx));

      await unitOfWork.run((ctx) => repo.severOriginatingReportId(targetReportId, ctx));

      const untouchedRow = await db.moderationActionAudit.findUnique({
        where: { id: untouchedEntry.id },
      });
      expect(untouchedRow?.originatingReportId).toBe(untouchedReportId);
    });

    it('returns 0 when re-running severance against a reportId already severed (idempotency)', async () => {
      const reportId = createId();
      const entry = buildRecord({ originatingReportId: reportId });
      await unitOfWork.run((ctx) => repo.record(entry, ctx));

      // First severance
      const firstCount = await unitOfWork.run((ctx) =>
        repo.severOriginatingReportId(reportId, ctx),
      );
      expect(firstCount).toBe(1);

      // Second severance — originatingReportId is already NULL, WHERE clause matches nothing
      const secondCount = await unitOfWork.run((ctx) =>
        repo.severOriginatingReportId(reportId, ctx),
      );
      expect(secondCount).toBe(0);
    });
  });
});
