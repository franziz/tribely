import { describe, expect, it, vi } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import { FakeUnitOfWork, FixedClock, TEST_TX } from '@/core/testing/fakes.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { Report } from '../../domain/entities/report.js';
import { ReportReason } from '../../domain/value-objects/report-reason.js';
import { ReportTarget } from '../../domain/value-objects/report-target.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import type {
  RecordModerationActionUseCase,
  RecordModerationActionInput,
} from '@/features/audit/application/usecases/record-moderation-action.usecase.js';
import { RecordExternalInputUseCase } from './record-external-input.usecase.js';

// ---------------------------------------------------------------------------
// Clock anchors
// ---------------------------------------------------------------------------

/** NOW is the operator's CLI invocation time (actedAt). */
const NOW = new Date('2026-05-26T10:00:00Z');

/** RECEIVED_AT is the operator-supplied time the external letter/email arrived. */
const RECEIVED_AT = new Date('2026-05-25T14:30:00Z');

// ---------------------------------------------------------------------------
// Helpers — aggregate factories
// ---------------------------------------------------------------------------

const makeEscalatedReport = (overrides: { resolved?: boolean } = {}): Report => {
  const report = Report.file({
    id: createId(),
    reporterUserId: createId(),
    target: ReportTarget.create('review', createId()),
    reason: ReportReason.create('spam'),
    comment: null,
    now: new Date('2026-05-20T00:00:00Z'),
  });
  report.escalate({
    category: 'external-jurisdiction',
    externalRef: 'MDA-2026-001',
    escalatedByUserId: createId(),
    now: new Date('2026-05-21T00:00:00Z'),
  });
  if (overrides.resolved) {
    report.resolve({
      resolution: 'kept',
      resolvedByUserId: createId(),
      now: new Date('2026-05-22T00:00:00Z'),
      externalInputCount: 1, // satisfy escalation resolve gate
    });
  }
  report.pullEvents(); // discard domain events — not under test here
  return report;
};

const makeNonEscalatedReport = (): Report => {
  const report = Report.file({
    id: createId(),
    reporterUserId: createId(),
    target: ReportTarget.create('review', createId()),
    reason: ReportReason.create('spam'),
    comment: null,
    now: new Date('2026-05-20T00:00:00Z'),
  });
  report.pullEvents();
  return report;
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
  listUnresolved = vi.fn();
  listOlderThan = vi.fn();
  listOpenOlderThan = vi.fn();
  listByReporter = vi.fn();
  deleteAllForUser = vi.fn();
  deleteById = vi.fn();
  findOrphanedOriginatingReportIds = vi.fn();
}

class FakeRecordModerationActionUseCase {
  readonly recorded: Array<{ input: RecordModerationActionInput; ctx: TxContext }> = [];
  execute(input: RecordModerationActionInput, ctx: TxContext): Promise<void> {
    this.recorded.push({ input, ctx });
    return Promise.resolve();
  }
}

// ---------------------------------------------------------------------------
// Test factory helpers
// ---------------------------------------------------------------------------

const makeUseCase = (report: Report | null) => {
  const reports = new FakeReportRepository(report);
  const audit = new FakeRecordModerationActionUseCase();
  const clock = new FixedClock(NOW);
  const uow = new FakeUnitOfWork();
  const useCase = new RecordExternalInputUseCase(
    uow,
    reports,
    audit as unknown as RecordModerationActionUseCase,
    clock,
  );
  return { useCase, reports, audit, uow };
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('RecordExternalInputUseCase', () => {
  describe('happy path', () => {
    it('writes an audit row with all expected fields for an escalated unresolved report', async () => {
      const report = makeEscalatedReport();
      const { useCase, audit } = makeUseCase(report);

      await useCase.execute({
        operatorUserId: 'op-1',
        reportId: report.id,
        source: 'counsel',
        disposition: 'Counsel advises no further action required.',
        receivedAt: RECEIVED_AT,
      });

      expect(audit.recorded).toHaveLength(1);
      const recorded = audit.recorded[0];
      expect(recorded).toBeDefined();

      // Action type
      expect(recorded!.input.action).toBe('record_external_input');

      // Operator and report linkage
      expect(recorded!.input.operatorUserId).toBe('op-1');
      expect(recorded!.input.reportId).toBe(report.id);
      expect(recorded!.input.targetType).toBe(report.target.type);
      expect(recorded!.input.targetId).toBe(report.target.id);
      expect(recorded!.input.reporterUserId).toBe(report.reporterUserId);

      // External input fields
      expect(recorded!.input.externalSource).toBe('counsel');
      expect(recorded!.input.externalDisposition).toBe('Counsel advises no further action required.');

      // actedAt = clock.now(); externalReceivedAt = input.receivedAt — DISTINCT times
      expect(recorded!.input.actedAt).toEqual(NOW);
      expect(recorded!.input.externalReceivedAt).toEqual(RECEIVED_AT);
      expect(recorded!.input.actedAt).not.toEqual(recorded!.input.externalReceivedAt);

      // Escalation category carried forward from report
      expect(recorded!.input.escalationCategory).toBe('external-jurisdiction');

      // Fields that are null by design for this action
      expect(recorded!.input.reason).toBeNull();
      expect(recorded!.input.contentSnapshot).toBeNull();
      expect(recorded!.input.reasonCode).toBeNull();
      expect(recorded!.input.justificationText).toBeNull();
      expect(recorded!.input.originatingReportId).toBeNull();
      expect(recorded!.input.externalRef).toBeNull();
    });

    it('passes the TxContext from the UnitOfWork to recordAudit', async () => {
      const report = makeEscalatedReport();
      const { useCase, audit } = makeUseCase(report);

      await useCase.execute({
        operatorUserId: 'op-1',
        reportId: report.id,
        source: 'imda',
        disposition: 'IMDA case closed.',
        receivedAt: RECEIVED_AT,
      });

      expect(audit.recorded[0]?.ctx).toBe(TEST_TX);
    });

    it('does NOT mutate the Report aggregate (no save call)', async () => {
      const report = makeEscalatedReport();
      const { useCase, reports } = makeUseCase(report);

      await useCase.execute({
        operatorUserId: 'op-1',
        reportId: report.id,
        source: 'partner',
        disposition: 'Partner confirmed content removal.',
        receivedAt: RECEIVED_AT,
      });

      expect(reports.saved).toHaveLength(0);
    });

    it('allows multiple invocations on the same report (no idempotency dedupe)', async () => {
      const report = makeEscalatedReport();
      const { useCase, audit } = makeUseCase(report);

      const input = {
        operatorUserId: 'op-1',
        reportId: report.id,
        source: 'counsel' as const,
        disposition: 'First counsel input.',
        receivedAt: RECEIVED_AT,
      };

      await useCase.execute(input);
      await useCase.execute({ ...input, disposition: 'Second counsel input.' });
      await useCase.execute({ ...input, disposition: 'Third counsel input.', source: 'imda' });

      expect(audit.recorded).toHaveLength(3);
    });

    it('carries escalationCategory forward for all four categories', async () => {
      const categories = [
        'criminal-content',
        'imminent-harm',
        'ambiguous-policy',
        'external-jurisdiction',
      ] as const;

      for (const category of categories) {
        const report = Report.file({
          id: createId(),
          reporterUserId: createId(),
          target: ReportTarget.create('review', createId()),
          reason: ReportReason.create('spam'),
          comment: null,
          now: new Date('2026-05-20T00:00:00Z'),
        });
        report.escalate({
          category,
          externalRef: 'REF-001',
          escalatedByUserId: createId(),
          now: new Date('2026-05-21T00:00:00Z'),
        });
        report.pullEvents();

        const { useCase, audit } = makeUseCase(report);
        await useCase.execute({
          operatorUserId: 'op-1',
          reportId: report.id,
          source: 'counsel',
          disposition: `Input for ${category}`,
          receivedAt: RECEIVED_AT,
        });

        const last = audit.recorded[audit.recorded.length - 1];
        expect(last?.input.escalationCategory).toBe(category);
      }
    });
  });

  describe('validation guard', () => {
    it('throws 400 reports.dispositionRequired for whitespace-only disposition', async () => {
      const report = makeEscalatedReport();
      const { useCase } = makeUseCase(report);

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          reportId: report.id,
          source: 'counsel',
          disposition: '   ',
          receivedAt: RECEIVED_AT,
        }),
      ).rejects.toMatchObject({
        status: 400,
        details: { subcode: 'reports.dispositionRequired' },
      });
    });

    it('throws 400 reports.dispositionRequired for empty-string disposition', async () => {
      const report = makeEscalatedReport();
      const { useCase } = makeUseCase(report);

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          reportId: report.id,
          source: 'other',
          disposition: '',
          receivedAt: RECEIVED_AT,
        }),
      ).rejects.toMatchObject({
        status: 400,
        details: { subcode: 'reports.dispositionRequired' },
      });
    });
  });

  describe('not-found guard', () => {
    it('throws 404 when report does not exist', async () => {
      const { useCase } = makeUseCase(null);

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          reportId: createId(),
          source: 'partner',
          disposition: 'Some input.',
          receivedAt: RECEIVED_AT,
        }),
      ).rejects.toMatchObject({ status: 404 });
    });
  });

  describe('non-escalated guard', () => {
    it('throws 409 reports.notEscalated when report has not been escalated', async () => {
      const report = makeNonEscalatedReport();
      const { useCase } = makeUseCase(report);

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          reportId: report.id,
          source: 'counsel',
          disposition: 'Some input.',
          receivedAt: RECEIVED_AT,
        }),
      ).rejects.toMatchObject({
        status: 409,
        details: { subcode: 'reports.notEscalated' },
      });
    });
  });

  describe('resolved guard', () => {
    it('throws 409 reports.reportAlreadyResolved when report is already resolved', async () => {
      const report = makeEscalatedReport({ resolved: true });
      const { useCase } = makeUseCase(report);

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          reportId: report.id,
          source: 'imda',
          disposition: 'Post-resolution input — should be rejected.',
          receivedAt: RECEIVED_AT,
        }),
      ).rejects.toMatchObject({
        status: 409,
        details: { subcode: 'reports.reportAlreadyResolved' },
      });
    });
  });

  describe('validation fires before report lookup', () => {
    it('throws 422 for whitespace disposition even if repository is not consulted', async () => {
      // Repository returns null — if validation runs after findById the error would be 404
      const { useCase, reports } = makeUseCase(null);

      await expect(
        useCase.execute({
          operatorUserId: 'op-1',
          reportId: createId(),
          source: 'other',
          disposition: '\t\n  ',
          receivedAt: RECEIVED_AT,
        }),
      ).rejects.toMatchObject({
        status: 400,
        details: { subcode: 'reports.dispositionRequired' },
      });

      // findById should never have been called
      expect(reports.saved).toHaveLength(0);
    });
  });
});
