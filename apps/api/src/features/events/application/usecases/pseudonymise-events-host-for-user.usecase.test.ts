import { createId } from '@paralleldrive/cuid2';
import { describe, expect, it } from 'vitest';

import { FakeEventRepository, TEST_TX } from './fakes.js';
import { PseudonymiseEventsHostForUserUseCase } from './pseudonymise-events-host-for-user.usecase.js';

describe('PseudonymiseEventsHostForUserUseCase', () => {
  it('returns updatedCount as reported by the repo', async () => {
    const repo = new FakeEventRepository();
    const useCase = new PseudonymiseEventsHostForUserUseCase(repo);

    const userId = createId();
    const pseudonymHostId = createId();

    // Override to return a known count.
    repo.pseudonymiseHostForUser = (_uid, _pid, _ctx) => Promise.resolve(3);

    const result = await useCase.execute({ userId, pseudonymHostId }, TEST_TX);
    expect(result).toEqual({ updatedCount: 3 });
  });

  it('passes caller-supplied userId and pseudonymHostId to the repo unchanged', async () => {
    const repo = new FakeEventRepository();
    let capturedUserId: string | null = null;
    let capturedPseudonym: string | null = null;
    repo.pseudonymiseHostForUser = (uid, pid, _ctx) => {
      capturedUserId = uid;
      capturedPseudonym = pid;
      return Promise.resolve(0);
    };

    const useCase = new PseudonymiseEventsHostForUserUseCase(repo);
    const userId = createId();
    const pseudonymHostId = createId();

    await useCase.execute({ userId, pseudonymHostId }, TEST_TX);

    expect(capturedUserId).toBe(userId);
    expect(capturedPseudonym).toBe(pseudonymHostId);
  });

  it('passes the caller-supplied TxContext directly to the repo without opening a new UoW (A7 exception)', async () => {
    // The two-arg execute(input, ctx) shape (A7 exception) requires that the
    // use case forwards the exact ctx the caller supplied — no nested UoW.
    const repo = new FakeEventRepository();
    let capturedCtx: unknown = null;
    repo.pseudonymiseHostForUser = (_uid, _pid, ctx) => {
      capturedCtx = ctx;
      return Promise.resolve(0);
    };

    const useCase = new PseudonymiseEventsHostForUserUseCase(repo);
    await useCase.execute({ userId: createId(), pseudonymHostId: createId() }, TEST_TX);

    expect(capturedCtx).toBe(TEST_TX);
  });
});
