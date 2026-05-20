import { describe, expect, it, vi } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork, TxContext } from '@/core/db/unit-of-work.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import { Report } from '../../domain/entities/report.js';
import { ReportReason } from '../../domain/value-objects/report-reason.js';
import { ReportTarget } from '../../domain/value-objects/report-target.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import { TouchReportUseCase } from './touch-report.usecase.js';

const makeUntouchedReport = (): Report => {
  const report = Report.file({
    id: createId(),
    reporterUserId: createId(),
    target: ReportTarget.create('review', createId()),
    reason: ReportReason.create('spam'),
    comment: null,
    now: new Date('2025-06-01T00:00:00Z'),
  });
  report.pullEvents();
  return report;
};

const makeDeps = (existingReport: Report | null) => {
  const runSpy = vi.fn((work: (ctx: TxContext) => Promise<unknown>) =>
    work({} as TxContext),
  ) as UnitOfWork['run'];
  const saveSpy = vi.fn((): Promise<void> => Promise.resolve());

  const unitOfWork: UnitOfWork = { run: runSpy };
  const reports: ReportRepository = {
    save: saveSpy,
    findById: vi.fn().mockResolvedValue(existingReport),
    listUnresolved: vi.fn(),
    listOlderThan: vi.fn(),
    listOpenOlderThan: vi.fn(),
    listByReporter: vi.fn(),
  };
  const clock: Clock = { now: vi.fn().mockReturnValue(new Date('2025-06-02T00:00:00Z')) };
  return { unitOfWork, reports, clock, runSpy, saveSpy };
};

describe('TouchReportUseCase', () => {
  it('sets firstReviewedAt and saves on first touch', async () => {
    const report = makeUntouchedReport();
    const deps = makeDeps(report);
    const useCase = new TouchReportUseCase(deps.unitOfWork, deps.reports, deps.clock);

    await useCase.execute({ moderatorUserId: createId(), reportId: report.id });

    expect(report.firstReviewedAt).not.toBeNull();
    expect(deps.runSpy).toHaveBeenCalledOnce();
    expect(deps.saveSpy).toHaveBeenCalledWith(report, expect.anything());
  });

  it('is idempotent — second touch does not re-save', async () => {
    const report = makeUntouchedReport();
    const deps = makeDeps(report);
    const useCase = new TouchReportUseCase(deps.unitOfWork, deps.reports, deps.clock);

    await useCase.execute({ moderatorUserId: createId(), reportId: report.id });
    const firstTouchedAt = report.firstReviewedAt;

    // Second touch — same report returned by stub
    await useCase.execute({ moderatorUserId: createId(), reportId: report.id });

    // firstReviewedAt unchanged
    expect(report.firstReviewedAt).toEqual(firstTouchedAt);
    // save only called once (first touch)
    expect(deps.runSpy).toHaveBeenCalledTimes(1);
  });

  it('throws 404 when report not found', async () => {
    const deps = makeDeps(null);
    const useCase = new TouchReportUseCase(deps.unitOfWork, deps.reports, deps.clock);

    await expect(
      useCase.execute({ moderatorUserId: createId(), reportId: createId() }),
    ).rejects.toThrow(AppError);
    await expect(
      useCase.execute({ moderatorUserId: createId(), reportId: createId() }),
    ).rejects.toMatchObject({ status: 404 });
  });
});
