// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { runWithContext } from '@/core/context/request-context.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';

import type { ModerationActionAuditRecord } from '../../domain/repositories/moderation-action-audit.repository.js';
import { ModerationActionAuditPrismaRepository } from './moderation-action-audit.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * DB-level append-only enforcement test for `moderation_action_audit` (TRI-206).
 *
 * Runs under the `tribely_app` runtime role in CI (Brief C sets DATABASE_URL to
 * that role). Locally, devs bootstrap the runtime role per README (Brief E).
 *
 * When DATABASE_URL points at a superuser connection the UPDATE/DELETE/TRUNCATE
 * tests WILL FAIL — that is the intended dev-safety signal from Brief E.
 *
 * Skipped when DATABASE_URL is unset so unit-only runs still pass.
 */
describe.skipIf(!dbUrl)('moderation_action_audit append-only enforcement (TRI-206)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let repo: ModerationActionAuditPrismaRepository;
  const trackedIds: string[] = [];

  const buildRecord = (
    overrides: Partial<ModerationActionAuditRecord> = {},
  ): ModerationActionAuditRecord => {
    const id = createId();
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
      actedAt: new Date('2026-05-26T10:00:00Z'),
      requestId: 'system:test.tri206.append-only',
      recordedAt: new Date('2026-05-26T10:00:01Z'),
      ...overrides,
    };
  };

  beforeAll(() => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    repo = new ModerationActionAuditPrismaRepository(db);
  });

  afterAll(async () => {
    if (!dbUrl) return;
    if (trackedIds.length > 0) {
      await db.moderationActionAudit
        .deleteMany({ where: { id: { in: trackedIds } } })
        .catch(() => null);
    }
    await db.$disconnect();
  });

  it('runtime role can INSERT (smoke — repo path)', async () => {
    const entry = buildRecord({ action: 'touch' });
    trackedIds.push(entry.id);

    await expect(
      runWithContext(
        { requestId: entry.requestId ?? 'system:test.tri206', actorUserId: null },
        () => unitOfWork.run((ctx) => repo.record(entry, ctx)),
      ),
    ).resolves.toBeUndefined();
  });

  it('runtime role can SELECT (smoke — repo path)', async () => {
    // countExternalInputs is the only public read on the repository (per domain
    // interface). A non-matching reportId gives 0 — valid smoke for SELECT access.
    const count = await repo.countExternalInputs(createId());
    expect(count).toBe(0);
  });

  it('runtime role CAN UPDATE originatingReportId (TRI-165 severance — sanctioned column)', async () => {
    // Insert a row with a non-null originatingReportId, then sever it via raw SQL
    // under the runtime role — same path the report-retention sweep takes.
    const entry = buildRecord({ originatingReportId: createId() });
    trackedIds.push(entry.id);
    await runWithContext(
      { requestId: entry.requestId ?? 'system:test.tri206.sever', actorUserId: null },
      () => unitOfWork.run((ctx) => repo.record(entry, ctx)),
    );

    // This must NOT throw — it is the sanctioned severance path.
    await db.$executeRawUnsafe(
      `UPDATE moderation_action_audit SET "originatingReportId" = NULL WHERE id = $1`,
      entry.id,
    );

    // Confirm the column was cleared.
    const row = await db.moderationActionAudit.findUnique({ where: { id: entry.id } });
    expect(row?.originatingReportId).toBeNull();
  });

  it('runtime role CANNOT UPDATE non-sanctioned columns — receives Postgres 42501 (append-only contract)', async () => {
    // `action` is a representative write-once column that has no severance exception.
    // An attempt to UPDATE it must be denied even though originatingReportId is now allowed.
    let threw = false;
    try {
      // Target a non-existent id — a no-op even with privilege, so no data is
      // mutated if the role somehow has permission.
      await db.$executeRawUnsafe(
        `UPDATE moderation_action_audit SET action = 'tampered' WHERE id = '00000000-0000-0000-0000-000000000000'`,
      );
    } catch (err) {
      threw = true;
      const msg = (err as Error).message;
      const code = (err as { code?: string }).code;
      const hasPermissionDenied = msg.includes(
        'permission denied for table moderation_action_audit',
      );
      const has42501 = code === '42501' || msg.includes('42501');
      expect(hasPermissionDenied || has42501).toBe(true);
    }
    expect(threw).toBe(true);
  });

  it('runtime role cannot DELETE — receives Postgres 42501', async () => {
    let threw = false;
    try {
      await db.$executeRawUnsafe(
        `DELETE FROM moderation_action_audit WHERE id = '00000000-0000-0000-0000-000000000000'`,
      );
    } catch (err) {
      threw = true;
      const msg = (err as Error).message;
      const code = (err as { code?: string }).code;
      const hasPermissionDenied = msg.includes(
        'permission denied for table moderation_action_audit',
      );
      const has42501 = code === '42501' || msg.includes('42501');
      expect(hasPermissionDenied || has42501).toBe(true);
    }
    expect(threw).toBe(true);
  });

  it('runtime role cannot TRUNCATE — receives Postgres 42501', async () => {
    let threw = false;
    try {
      await db.$executeRawUnsafe(`TRUNCATE moderation_action_audit`);
    } catch (err) {
      threw = true;
      const msg = (err as Error).message;
      const code = (err as { code?: string }).code;
      const hasPermissionDenied = msg.includes(
        'permission denied for table moderation_action_audit',
      );
      const has42501 = code === '42501' || msg.includes('42501');
      expect(hasPermissionDenied || has42501).toBe(true);
    }
    expect(threw).toBe(true);
  });

  it('audit table is NOT owned by the runtime role (binding per legal-compliance)', async () => {
    // If a future operator accidentally runs ALTER TABLE ... OWNER TO tribely_app,
    // TRUNCATE becomes legal and this test fails loudly — the intended safety net.
    // The check is role-independent: we assert the owner is never `tribely_app`
    // regardless of which role runs this test (superuser locally, tribely_app in CI).
    const [tableRow] = await db.$queryRaw<Array<{ tableowner: string }>>`
        SELECT tableowner
        FROM pg_tables
        WHERE tablename = 'moderation_action_audit'
          AND schemaname = 'public'
      `;

    if (!tableRow)
      throw new Error('unexpected: pg_tables returned no row for moderation_action_audit');
    expect(tableRow.tableowner).not.toBe('tribely_app');
  });
});
