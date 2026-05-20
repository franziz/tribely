// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import { Report } from '../../domain/entities/report.js';
import { ReportReason } from '../../domain/value-objects/report-reason.js';
import { ReportTarget } from '../../domain/value-objects/report-target.js';
import { ReportComment } from '../../domain/value-objects/report-comment.js';
import { ReportPrismaRepository } from './report.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

describe.skipIf(!dbUrl)('ReportPrismaRepository — integration', () => {
  let db: PrismaClient;
  let repo: ReportPrismaRepository;
  let uow: PrismaUnitOfWork;

  // Shared test user + review IDs seeded per-suite.
  let reporterId: string;
  let targetReviewId: string;
  // Minimal User row for FK satisfaction — reports only need reporterUserId FK.
  // targetId is stored as plain string (polymorphic) — no FK constraint.

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    repo = new ReportPrismaRepository(db);
    uow = new PrismaUnitOfWork(db);

    // Seed minimal User row for reporterUserId FK.
    reporterId = createId();
    targetReviewId = createId();

    await db.user.create({
      data: {
        id: reporterId,
        email: `reporter-rep-test-${reporterId}@example.com`,
        displayName: 'Reporter',
      },
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;
    await db.report.deleteMany({ where: { reporterUserId: reporterId } });
    await db.user.deleteMany({ where: { id: reporterId } });
    await db.$disconnect();
  });

  const makeReport = (
    overrides: Partial<{
      reporterUserId: string;
      targetId: string;
      reason: string;
      comment: string | null;
      now: Date;
    }> = {},
  ): Report => {
    const report = Report.file({
      id: createId(),
      reporterUserId: overrides.reporterUserId ?? reporterId,
      target: ReportTarget.create('review', overrides.targetId ?? targetReviewId),
      reason: ReportReason.create(overrides.reason ?? 'spam'),
      comment: ReportComment.create(overrides.comment ?? null),
      now: overrides.now ?? new Date(),
    });
    report.pullEvents(); // discard events — not under test here
    return report;
  };

  it('saves and retrieves a report', async () => {
    const report = makeReport();
    await uow.run(async (ctx) => {
      await repo.save(report, ctx);
    });

    const loaded = await repo.findById(report.id);
    expect(loaded).not.toBeNull();
    expect(loaded?.id).toBe(report.id);
    expect(loaded?.reason.value).toBe('spam');
    expect(loaded?.comment).toBeNull();
    expect(loaded?.firstReviewedAt).toBeNull();
    expect(loaded?.resolvedAt).toBeNull();
    expect(loaded?.isResolved).toBe(false);
  });

  it('saves a report with a comment', async () => {
    const report = makeReport({ comment: 'This is clearly spam.' });
    await uow.run(async (ctx) => {
      await repo.save(report, ctx);
    });

    const loaded = await repo.findById(report.id);
    expect(loaded?.comment?.value).toBe('This is clearly spam.');
  });

  it('findById returns null for unknown id', async () => {
    const result = await repo.findById(createId());
    expect(result).toBeNull();
  });

  it('save updates existing report (upsert) — touch then resolve', async () => {
    const report = makeReport();
    await uow.run(async (ctx) => {
      await repo.save(report, ctx);
    });

    const touchAt = new Date(Date.now() + 1000);
    report.touch(touchAt);
    await uow.run(async (ctx) => {
      await repo.save(report, ctx);
    });

    const afterTouch = await repo.findById(report.id);
    expect(afterTouch?.firstReviewedAt).not.toBeNull();

    const resolveAt = new Date(Date.now() + 2000);
    report.resolve({ resolution: 'hidden', resolvedByUserId: reporterId, now: resolveAt });
    report.pullEvents();
    await uow.run(async (ctx) => {
      await repo.save(report, ctx);
    });

    const afterResolve = await repo.findById(report.id);
    expect(afterResolve?.isResolved).toBe(true);
    expect(afterResolve?.resolution).toBe('hidden');
    expect(afterResolve?.resolvedByUserId).toBe(reporterId);
  });

  it('listUnresolved returns only unresolved reports', async () => {
    const unresolved = makeReport();
    const resolved = makeReport();
    await uow.run(async (ctx) => {
      await repo.save(unresolved, ctx);
      await repo.save(resolved, ctx);
    });

    // Resolve one.
    resolved.resolve({ resolution: 'kept', resolvedByUserId: reporterId, now: new Date() });
    resolved.pullEvents();
    await uow.run(async (ctx) => {
      await repo.save(resolved, ctx);
    });

    const { rows } = await repo.listUnresolved({});
    const ids = rows.map((r) => r.id);
    expect(ids).toContain(unresolved.id);
    expect(ids).not.toContain(resolved.id);
  });

  it('listOlderThan returns resolved reports before cutoff', async () => {
    const past = new Date('2020-01-01T00:00:00Z');
    const reportOld = makeReport({ now: past });
    await uow.run(async (ctx) => {
      await repo.save(reportOld, ctx);
    });

    const resolvedAt = new Date('2020-06-01T00:00:00Z');
    reportOld.resolve({ resolution: 'kept', resolvedByUserId: reporterId, now: resolvedAt });
    reportOld.pullEvents();
    await uow.run(async (ctx) => {
      await repo.save(reportOld, ctx);
    });

    const cutoff = new Date('2021-01-01T00:00:00Z');
    const rows = await repo.listOlderThan({ resolvedAtBefore: cutoff });
    expect(rows.some((r) => r.id === reportOld.id)).toBe(true);
  });

  it('listOpenOlderThan returns unresolved reports before createdAt cutoff', async () => {
    const past = new Date('2019-01-01T00:00:00Z');
    const oldUnresolved = makeReport({ now: past });
    await uow.run(async (ctx) => {
      await repo.save(oldUnresolved, ctx);
    });

    const cutoff = new Date('2020-01-01T00:00:00Z');
    const rows = await repo.listOpenOlderThan({ createdAtBefore: cutoff });
    expect(rows.some((r) => r.id === oldUnresolved.id)).toBe(true);
  });

  it('listByReporter returns reports by a specific reporter', async () => {
    const report = makeReport();
    await uow.run(async (ctx) => {
      await repo.save(report, ctx);
    });

    const { rows } = await repo.listByReporter({ reporterUserId: reporterId });
    expect(rows.some((r) => r.id === report.id)).toBe(true);
  });
});
