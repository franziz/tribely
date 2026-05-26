import { describe, expect, it, vi } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork, TxContext } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import type { ReviewRepository } from '@/features/reviews/domain/repositories/review.repository.js';
import { FileReportUseCase } from './file-report.usecase.js';

const makeReviewRepo = (review: unknown): ReviewRepository => ({
  findById: vi.fn().mockResolvedValue(review),
  findByTriple: vi.fn(),
  findExistingTriples: vi.fn().mockResolvedValue(new Set()),
  save: vi.fn(),
  listByRatedUser: vi.fn(),
  listWrittenBy: vi.fn(),
  aggregateForUser: vi.fn(),
  deleteAllForUser: vi.fn(),
});

const makeDeps = (review: unknown) => {
  const runSpy = vi.fn((work: (ctx: TxContext) => Promise<unknown>) =>
    work({} as TxContext),
  ) as UnitOfWork['run'];
  const saveSpy = vi.fn((): Promise<void> => Promise.resolve());
  const publishSpy = vi.fn((): Promise<void> => Promise.resolve());

  const unitOfWork: UnitOfWork = { run: runSpy };
  const reports: ReportRepository = {
    save: saveSpy,
    findById: vi.fn(),
    listUnresolved: vi.fn(),
    listOlderThan: vi.fn(),
    listOpenOlderThan: vi.fn(),
    listByReporter: vi.fn(),
    deleteAllForUser: vi.fn(),
    deleteById: vi.fn(),
    findOrphanedOriginatingReportIds: vi.fn(),
  };
  const reviews = makeReviewRepo(review);
  const publisher: EventPublisher = { publish: publishSpy };
  const clock: Clock = { now: vi.fn().mockReturnValue(new Date('2025-06-01T00:00:00Z')) };

  return { unitOfWork, reports, reviews, publisher, clock, runSpy, saveSpy, publishSpy };
};

const validInput = {
  reporterUserId: createId(),
  targetType: 'review',
  targetId: createId(),
  reason: 'spam',
};

describe('FileReportUseCase', () => {
  it('saves report and publishes event on success', async () => {
    const fakeReview = { id: validInput.targetId };
    const deps = makeDeps(fakeReview);
    const useCase = new FileReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.reviews,
      deps.publisher,
      deps.clock,
    );

    const result = await useCase.execute(validInput);

    expect(result.reportId).toBeTypeOf('string');
    expect(deps.runSpy).toHaveBeenCalledOnce();
    expect(deps.saveSpy).toHaveBeenCalledOnce();
    expect(deps.publishSpy).toHaveBeenCalledOnce();
  });

  it('throws 422 when target type is user (not-implemented)', async () => {
    const deps = makeDeps(null);
    const useCase = new FileReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.reviews,
      deps.publisher,
      deps.clock,
    );

    await expect(useCase.execute({ ...validInput, targetType: 'user' })).rejects.toThrow(AppError);
    await expect(useCase.execute({ ...validInput, targetType: 'user' })).rejects.toThrow(
      /not yet supported/,
    );
  });

  it('throws 422 when target type is event (not-implemented)', async () => {
    const deps = makeDeps(null);
    const useCase = new FileReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.reviews,
      deps.publisher,
      deps.clock,
    );

    await expect(useCase.execute({ ...validInput, targetType: 'event' })).rejects.toThrow(AppError);
    await expect(useCase.execute({ ...validInput, targetType: 'event' })).rejects.toThrow(
      /not yet supported/,
    );
  });

  it('throws 404 when review target is not-found', async () => {
    const deps = makeDeps(null);
    const useCase = new FileReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.reviews,
      deps.publisher,
      deps.clock,
    );

    await expect(useCase.execute(validInput)).rejects.toThrow(AppError);
    await expect(useCase.execute(validInput)).rejects.toMatchObject({ status: 404 });
  });

  it('does not save or publish when review is not found', async () => {
    const deps = makeDeps(null);
    const useCase = new FileReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.reviews,
      deps.publisher,
      deps.clock,
    );

    await expect(useCase.execute(validInput)).rejects.toThrow();
    expect(deps.saveSpy).not.toHaveBeenCalled();
    expect(deps.publishSpy).not.toHaveBeenCalled();
  });

  it('includes optional comment when provided', async () => {
    const fakeReview = { id: validInput.targetId };
    const deps = makeDeps(fakeReview);
    const useCase = new FileReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.reviews,
      deps.publisher,
      deps.clock,
    );

    const result = await useCase.execute({ ...validInput, comment: 'this is a comment' });
    expect(result.reportId).toBeTypeOf('string');
  });
});
