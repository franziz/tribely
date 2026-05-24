import { describe, expect, it, vi } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork, TxContext } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { HideReviewUseCase } from '@/features/reviews/application/usecases/hide-review.usecase.js';
import { Report } from '../../domain/entities/report.js';
import { ReportReason } from '../../domain/value-objects/report-reason.js';
import { ReportTarget } from '../../domain/value-objects/report-target.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import { ResolveReportUseCase } from './resolve-report.usecase.js';

const makeReport = (): Report => {
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
  const publishSpy = vi.fn((): Promise<void> => Promise.resolve());
  const hideExecuteSpy = vi.fn((): Promise<void> => Promise.resolve());

  const unitOfWork: UnitOfWork = { run: runSpy };
  const reports: ReportRepository = {
    save: saveSpy,
    findById: vi.fn().mockResolvedValue(existingReport),
    listUnresolved: vi.fn(),
    listOlderThan: vi.fn(),
    listOpenOlderThan: vi.fn(),
    listByReporter: vi.fn(),
    deleteAllForUser: vi.fn(),
  };
  const hideReview = { execute: hideExecuteSpy } as unknown as HideReviewUseCase;
  const publisher: EventPublisher = { publish: publishSpy };
  const clock: Clock = { now: vi.fn().mockReturnValue(new Date('2025-06-02T00:00:00Z')) };
  return {
    unitOfWork,
    reports,
    hideReview,
    publisher,
    clock,
    runSpy,
    saveSpy,
    publishSpy,
    hideExecuteSpy,
  };
};

describe('ResolveReportUseCase', () => {
  it('resolves a report with resolution=kept', async () => {
    const report = makeReport();
    const deps = makeDeps(report);
    const useCase = new ResolveReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.hideReview,
      deps.publisher,
      deps.clock,
    );

    await useCase.execute({ moderatorUserId: createId(), reportId: report.id, resolution: 'kept' });

    expect(report.isResolved).toBe(true);
    expect(report.resolution).toBe('kept');
    expect(deps.runSpy).toHaveBeenCalledOnce();
    expect(deps.saveSpy).toHaveBeenCalledOnce();
    expect(deps.publishSpy).toHaveBeenCalledOnce();
    expect(deps.hideExecuteSpy).not.toHaveBeenCalled();
  });

  it('resolves with hidden and calls hideReview when alsoHideReviewId provided', async () => {
    const report = makeReport();
    const deps = makeDeps(report);
    const useCase = new ResolveReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.hideReview,
      deps.publisher,
      deps.clock,
    );
    const reviewId = createId();

    await useCase.execute({
      moderatorUserId: createId(),
      reportId: report.id,
      resolution: 'hidden',
      alsoHideReviewId: reviewId,
    });

    expect(report.resolution).toBe('hidden');
    expect(deps.hideExecuteSpy).toHaveBeenCalledOnce();
    expect(deps.hideExecuteSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        reviewId,
        reportId: report.id,
      }),
    );
  });

  it('does NOT call hideReview when resolution=hidden but no alsoHideReviewId', async () => {
    const report = makeReport();
    const deps = makeDeps(report);
    const useCase = new ResolveReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.hideReview,
      deps.publisher,
      deps.clock,
    );

    await useCase.execute({
      moderatorUserId: createId(),
      reportId: report.id,
      resolution: 'hidden',
    });

    expect(deps.hideExecuteSpy).not.toHaveBeenCalled();
  });

  it('throws ReportAlreadyResolved on second resolve (append-only invariant)', async () => {
    const report = makeReport();
    const deps = makeDeps(report);
    const useCase = new ResolveReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.hideReview,
      deps.publisher,
      deps.clock,
    );
    const moderatorId = createId();

    await useCase.execute({
      moderatorUserId: moderatorId,
      reportId: report.id,
      resolution: 'kept',
    });

    await expect(
      useCase.execute({ moderatorUserId: moderatorId, reportId: report.id, resolution: 'kept' }),
    ).rejects.toThrow(AppError);
    await expect(
      useCase.execute({ moderatorUserId: moderatorId, reportId: report.id, resolution: 'kept' }),
    ).rejects.toMatchObject({ status: 409 });
  });

  it('throws 404 when report not found', async () => {
    const deps = makeDeps(null);
    const useCase = new ResolveReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.hideReview,
      deps.publisher,
      deps.clock,
    );

    await expect(
      useCase.execute({ moderatorUserId: createId(), reportId: createId(), resolution: 'kept' }),
    ).rejects.toThrow(AppError);
    await expect(
      useCase.execute({ moderatorUserId: createId(), reportId: createId(), resolution: 'kept' }),
    ).rejects.toMatchObject({ status: 404 });
  });
});
