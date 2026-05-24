import { createId } from '@paralleldrive/cuid2';
import { describe, expect, it } from 'vitest';

import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { ReviewRepository } from '../../domain/repositories/review.repository.js';
import { CascadeReviewsOnUserDeletionUseCase } from './cascade-reviews-on-user-deletion.usecase.js';

const TEST_TX: TxContext = { __brand: 'TxContext' };

/**
 * Minimal fake — only the method under test needs to exist.
 */
const makeFakeRepo = (): Pick<ReviewRepository, 'deleteAllForUser'> & {
  deleteAllForUser: (userId: string, ctx: TxContext) => Promise<number>;
} => ({
  deleteAllForUser: (_userId, _ctx) => Promise.resolve(0),
});

describe('CascadeReviewsOnUserDeletionUseCase', () => {
  it('calls deleteAllForUser with the supplied userId and ctx', async () => {
    let capturedUserId: string | null = null;
    let capturedCtx: unknown = null;

    const repo = makeFakeRepo();
    repo.deleteAllForUser = (userId, ctx) => {
      capturedUserId = userId;
      capturedCtx = ctx;
      return Promise.resolve(1);
    };

    const useCase = new CascadeReviewsOnUserDeletionUseCase(repo as unknown as ReviewRepository);
    const userId = createId();

    await useCase.execute({ userId }, TEST_TX);

    expect(capturedUserId).toBe(userId);
    expect(capturedCtx).toBe(TEST_TX);
  });

  it('returns void (does not surface the deleted row count)', async () => {
    const repo = makeFakeRepo();
    repo.deleteAllForUser = (_userId, _ctx) => Promise.resolve(42);

    const useCase = new CascadeReviewsOnUserDeletionUseCase(repo as unknown as ReviewRepository);

    // The port contract is Promise<void> — callers cannot observe the count.
    await expect(useCase.execute({ userId: createId() }, TEST_TX)).resolves.toBeUndefined();
  });

  it('does NOT open its own UoW — no UnitOfWork injected and no error thrown (A7 exception)', async () => {
    // The two-arg execute(input, ctx) shape deliberately has no unitOfWork
    // dependency. Constructing the use case without one (and receiving no
    // injection error) verifies the A7-exception shape is in place.
    const repo = makeFakeRepo();
    const useCase = new CascadeReviewsOnUserDeletionUseCase(repo as unknown as ReviewRepository);

    // Should resolve cleanly with no UnitOfWork available.
    await expect(useCase.execute({ userId: createId() }, TEST_TX)).resolves.toBeUndefined();
  });
});
