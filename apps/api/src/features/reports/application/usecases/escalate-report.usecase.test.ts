import { describe, expect, it } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import { FakeUnitOfWork, FakeEventPublisher, FixedClock, TEST_TX } from '@/core/testing/fakes.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { Report } from '../../domain/entities/report.js';
import { ReportReason } from '../../domain/value-objects/report-reason.js';
import { ReportTarget } from '../../domain/value-objects/report-target.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import type { RecordModerationActionUseCase } from '@/features/audit/application/usecases/record-moderation-action.usecase.js';
import type { RecordModerationActionInput } from '@/features/audit/application/usecases/record-moderation-action.usecase.js';
import { EscalateReportUseCase } from './escalate-report.usecase.js';

const NOW = new Date('2026-05-26T10:00:00Z');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const makeReport = (): Report => {
  const report = Report.file({
    id: createId(),
    reporterUserId: createId(),
    target: ReportTarget.create('review', createId()),
    reason: ReportReason.create('spam'),
    comment: null,
    now: new Date('2026-05-20T00:00:00Z'),
  });
  report.pullEvents(); // discard filed event
  return report;
};

const makeResolvedReport = (): Report => {
  const report = makeReport();
  return Report.rehydrate({
    id: report.id,
    reporterUserId: report.reporterUserId,
    target: report.target,
    reason: report.reason,
    comment: report.comment,
    createdAt: report.createdAt,
    firstReviewedAt: null,
    resolvedAt: new Date('2026-05-21T00:00:00Z'),
    resolution: 'kept',
    resolvedByUserId: createId(),
  });
};

const makeEscalatedReport = (): Report => {
  const report = makeReport();
  return Report.rehydrate({
    id: report.id,
    reporterUserId: report.reporterUserId,
    target: report.target,
    reason: report.reason,
    comment: report.comment,
    createdAt: report.createdAt,
    firstReviewedAt: null,
    resolvedAt: null,
    resolution: null,
    resolvedByUserId: null,
    escalatedAt: new Date('2026-05-22T00:00:00Z'),
    escalationCategory: 'ambiguous-policy',
    externalRef: 'CASE-001',
    escalatedByUserId: createId(),
  });
};

// ---------------------------------------------------------------------------
// Fake implementations
// ---------------------------------------------------------------------------

class FakeReportRepository implements ReportRepository {
  private _report: Report | null;
  readonly saved: Report[] = [];

  constructor(report: Report | null = null) {
    this._report = report;
  }

  save(report: Report, _ctx?: TxContext): Promise<void> {
    this.saved.push(report);
    return Promise.resolve();
  }
  findById(_id: string, _ctx?: TxContext): Promise<Report | null> {
    return Promise.resolve(this._report);
  }
  listUnresolved = () => Promise.resolve({ rows: [], nextCursor: null });
  listOlderThan = () => Promise.resolve([]);
  listOpenOlderThan = () => Promise.resolve([]);
  listByReporter = () => Promise.resolve({ rows: [], nextCursor: null });
  deleteAllForUser = () => Promise.resolve(0);
  deleteById = () => Promise.resolve();
  findOrphanedOriginatingReportIds = () => Promise.resolve([]);
}

class FakeRecordModerationActionUseCase {
  readonly recorded: Array<{ input: RecordModerationActionInput; ctx: TxContext }> = [];
  execute(input: RecordModerationActionInput, ctx: TxContext): Promise<void> {
    this.recorded.push({ input, ctx });
    return Promise.resolve();
  }
}

// ---------------------------------------------------------------------------
// Factory for the system under test
// ---------------------------------------------------------------------------

interface Deps {
  report?: Report | null;
}

const buildSut = (deps: Deps = {}) => {
  const reportToReturn = 'report' in deps ? (deps.report ?? null) : null;
  const reports = new FakeReportRepository(reportToReturn);
  const publisher = new FakeEventPublisher();
  const audit = new FakeRecordModerationActionUseCase();
  const clock = new FixedClock(NOW);

  const useCase = new EscalateReportUseCase(
    new FakeUnitOfWork(),
    reports,
    publisher,
    audit as unknown as RecordModerationActionUseCase,
    clock,
  );

  return { useCase, reports, publisher, audit };
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('EscalateReportUseCase', () => {
  describe('happy path', () => {
    it('escalates an open report, saves it, publishes event, and records audit row', async () => {
      const report = makeReport();
      const { useCase, reports, publisher, audit } = buildSut({ report });

      await useCase.execute({
        operatorUserId: 'op-1',
        reportId: report.id,
        category: 'ambiguous-policy',
        externalRef: 'CASE-42',
        note: 'Escalating for legal review',
      });

      // Report state
      expect(report.isEscalated).toBe(true);
      expect(report.escalationCategory).toBe('ambiguous-policy');
      expect(report.externalRef).toBe('CASE-42');
      expect(report.escalatedByUserId).toBe('op-1');
      expect(report.escalatedAt).toEqual(NOW);

      // Persistence
      expect(reports.saved).toHaveLength(1);
      expect(reports.saved[0]).toBe(report);

      // Event emission
      expect(publisher.published.length).toBeGreaterThanOrEqual(1);
      const escalatedEvent = publisher.published.find((e) => e.type === 'reports.reportEscalated');
      expect(escalatedEvent).toBeDefined();

      // Audit row
      expect(audit.recorded).toHaveLength(1);
      const auditEntry = audit.recorded[0];
      expect(auditEntry).toBeDefined();
      if (!auditEntry) throw new Error('unreachable');
      const auditRow = auditEntry.input;
      expect(auditRow.action).toBe('escalate');
      expect(auditRow.operatorUserId).toBe('op-1');
      expect(auditRow.reportId).toBe(report.id);
      expect(auditRow.targetType).toBe(report.target.type);
      expect(auditRow.targetId).toBe(report.target.id);
      expect(auditRow.reason).toBe('Escalating for legal review');
      expect(auditRow.escalationCategory).toBe('ambiguous-policy');
      expect(auditRow.externalRef).toBe('CASE-42');
      expect(auditRow.contentSnapshot).toBeNull();
      expect(auditRow.reasonCode).toBeNull();
      expect(auditRow.justificationText).toBeNull();
      expect(auditRow.originatingReportId).toBeNull();
      expect(auditRow.externalSource).toBeNull();
      expect(auditRow.externalDisposition).toBeNull();
      expect(auditRow.externalReceivedAt).toBeNull();
      expect(auditRow.actedAt).toEqual(NOW);
    });

    it('records null audit reason when note is null', async () => {
      const report = makeReport();
      const { useCase, audit } = buildSut({ report });

      await useCase.execute({
        operatorUserId: 'op-1',
        reportId: report.id,
        category: 'criminal-content',
        externalRef: 'CASE-99',
        note: null,
      });

      const entry = audit.recorded[0];
      expect(entry).toBeDefined();
      if (!entry) throw new Error('unreachable');
      expect(entry.input.reason).toBeNull();
    });

    it('passes the TxContext through to save, publish, and audit atomically', async () => {
      const report = makeReport();
      const capturedCtxValues: TxContext[] = [];
      const auditCapturing = {
        execute(input: RecordModerationActionInput, ctx: TxContext): Promise<void> {
          capturedCtxValues.push(ctx);
          return Promise.resolve();
        },
      };

      const useCase = new EscalateReportUseCase(
        new FakeUnitOfWork(),
        new FakeReportRepository(report),
        new FakeEventPublisher(),
        auditCapturing as unknown as RecordModerationActionUseCase,
        new FixedClock(NOW),
      );

      await useCase.execute({
        operatorUserId: 'op-1',
        reportId: report.id,
        category: 'external-jurisdiction',
        externalRef: 'SPF-001',
        note: null,
      });

      expect(capturedCtxValues).toHaveLength(1);
      expect(capturedCtxValues[0]).toBe(TEST_TX);
    });
  });

  describe('error branches', () => {
    it('throws 400 when externalRef is blank (whitespace-only)', async () => {
      const report = makeReport();
      const { useCase } = buildSut({ report });

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          reportId: report.id,
          category: 'ambiguous-policy',
          externalRef: '   ',
          note: null,
        }),
      ).rejects.toMatchObject({ status: 400 });
    });

    it('throws 400 when externalRef is empty string', async () => {
      const report = makeReport();
      const { useCase } = buildSut({ report });

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          reportId: report.id,
          category: 'ambiguous-policy',
          externalRef: '',
          note: null,
        }),
      ).rejects.toMatchObject({ status: 400 });
    });

    it('throws 404 when report not found', async () => {
      const { useCase } = buildSut({ report: null });

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          reportId: createId(),
          category: 'ambiguous-policy',
          externalRef: 'CASE-42',
          note: null,
        }),
      ).rejects.toMatchObject({ status: 404 });
    });

    it('throws 409 (reports.reportAlreadyResolved) when report is already resolved', async () => {
      const report = makeResolvedReport();
      const { useCase } = buildSut({ report });

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          reportId: report.id,
          category: 'ambiguous-policy',
          externalRef: 'CASE-42',
          note: null,
        }),
      ).rejects.toMatchObject({ status: 409 });
    });

    it('throws 409 (reports.reportAlreadyEscalated) when report is already escalated', async () => {
      const report = makeEscalatedReport();
      const { useCase } = buildSut({ report });

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          reportId: report.id,
          category: 'criminal-content',
          externalRef: 'CASE-43',
          note: null,
        }),
      ).rejects.toMatchObject({ status: 409 });
    });
  });
});
