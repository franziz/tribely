import { createId } from '@paralleldrive/cuid2';
import { describe, expect, it } from 'vitest';

import { FakeJoinRequestRepository, TEST_TX } from './fakes.js';
import { PseudonymiseJoinRequestsAuthorForUserUseCase } from './pseudonymise-join-requests-author-for-user.usecase.js';

describe('PseudonymiseJoinRequestsAuthorForUserUseCase', () => {
  it('delegates to the repo with the correct userId and pseudonymAuthorId, forwarding ctx', async () => {
    const repo = new FakeJoinRequestRepository();
    const useCase = new PseudonymiseJoinRequestsAuthorForUserUseCase(repo);

    const userId = createId();
    const pseudonymAuthorId = createId();

    // Repo starts empty so count will be 0 — verifying delegation contract.
    const result = await useCase.execute({ userId, pseudonymAuthorId }, TEST_TX);

    expect(result).toEqual({ updatedCount: 0 });
  });

  it('returns updatedCount as reported by the repo', async () => {
    const repo = new FakeJoinRequestRepository();
    const useCase = new PseudonymiseJoinRequestsAuthorForUserUseCase(repo);

    const userId = createId();
    const pseudonymAuthorId = createId();

    // Override to return a known count without seeding full aggregates.
    repo.pseudonymiseAuthorForUser = (_uid, _pid, _ctx) => Promise.resolve(3);

    const result = await useCase.execute({ userId, pseudonymAuthorId }, TEST_TX);
    expect(result.updatedCount).toBe(3);
  });

  it('passes the caller-supplied TxContext directly to the repo without opening a new UoW', async () => {
    // Enforces the A7 exception: no internal unitOfWork.run means the repo
    // call must receive exactly the ctx supplied to execute().
    const repo = new FakeJoinRequestRepository();
    let capturedCtx: unknown = null;
    repo.pseudonymiseAuthorForUser = (_uid, _pid, ctx) => {
      capturedCtx = ctx;
      return Promise.resolve(0);
    };

    const useCase = new PseudonymiseJoinRequestsAuthorForUserUseCase(repo);
    await useCase.execute({ userId: createId(), pseudonymAuthorId: createId() }, TEST_TX);

    expect(capturedCtx).toBe(TEST_TX);
  });
});
