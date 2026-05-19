import { describe, expect, it, vi } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork, TxContext } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import type { TargetResolver } from '../services/target-resolver.js';
import { FileReportUseCase } from './file-report.usecase.js';

const makeDeps = (resolverResult: Awaited<ReturnType<TargetResolver['resolve']>>) => {
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
  };
  const resolver: TargetResolver = {
    resolve: vi.fn().mockResolvedValue(resolverResult),
  } as unknown as TargetResolver;
  const publisher: EventPublisher = { publish: publishSpy };
  const clock: Clock = { now: vi.fn().mockReturnValue(new Date('2025-06-01T00:00:00Z')) };

  return { unitOfWork, reports, resolver, publisher, clock, runSpy, saveSpy, publishSpy };
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
    const deps = makeDeps({ kind: 'review', review: fakeReview as never });
    const useCase = new FileReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.resolver,
      deps.publisher,
      deps.clock,
    );

    const result = await useCase.execute(validInput);

    expect(result.reportId).toBeTypeOf('string');
    expect(deps.runSpy).toHaveBeenCalledOnce();
    expect(deps.saveSpy).toHaveBeenCalledOnce();
    expect(deps.publishSpy).toHaveBeenCalledOnce();
  });

  it('throws 422 when target type is not-implemented', async () => {
    const deps = makeDeps({ kind: 'not-implemented' });
    const useCase = new FileReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.resolver,
      deps.publisher,
      deps.clock,
    );

    await expect(useCase.execute({ ...validInput, targetType: 'user' })).rejects.toThrow(AppError);
    await expect(useCase.execute({ ...validInput, targetType: 'user' })).rejects.toThrow(
      /not yet supported/,
    );
  });

  it('throws 404 when target is not-found', async () => {
    const deps = makeDeps({ kind: 'not-found' });
    const useCase = new FileReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.resolver,
      deps.publisher,
      deps.clock,
    );

    await expect(useCase.execute(validInput)).rejects.toThrow(AppError);
    await expect(useCase.execute(validInput)).rejects.toMatchObject({ status: 404 });
  });

  it('does not save or publish when resolver rejects', async () => {
    const deps = makeDeps({ kind: 'not-found' });
    const useCase = new FileReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.resolver,
      deps.publisher,
      deps.clock,
    );

    await expect(useCase.execute(validInput)).rejects.toThrow();
    expect(deps.saveSpy).not.toHaveBeenCalled();
    expect(deps.publishSpy).not.toHaveBeenCalled();
  });

  it('includes optional comment when provided', async () => {
    const fakeReview = { id: validInput.targetId };
    const deps = makeDeps({ kind: 'review', review: fakeReview as never });
    const useCase = new FileReportUseCase(
      deps.unitOfWork,
      deps.reports,
      deps.resolver,
      deps.publisher,
      deps.clock,
    );

    const result = await useCase.execute({ ...validInput, comment: 'this is a comment' });
    expect(result.reportId).toBeTypeOf('string');
  });
});
