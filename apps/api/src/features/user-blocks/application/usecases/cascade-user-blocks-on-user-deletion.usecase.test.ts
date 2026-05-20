import { createId } from '@paralleldrive/cuid2';
import { describe, expect, it } from 'vitest';

import { TEST_TX } from '@/core/testing/fakes.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { UserBlock } from '../../domain/entities/user-block.js';
import type { UserBlockRepository } from '../../domain/repositories/user-block.repository.js';
import { CascadeUserBlocksOnUserDeletionUseCase } from './cascade-user-blocks-on-user-deletion.usecase.js';

class FakeUserBlockRepository implements UserBlockRepository {
  deleteAllForUserCalls: Array<{ userId: string; ctx: TxContext }> = [];
  deleteAllForUserResult = 0;

  deleteAllForUser(userId: string, ctx: TxContext): Promise<number> {
    this.deleteAllForUserCalls.push({ userId, ctx });
    return Promise.resolve(this.deleteAllForUserResult);
  }

  save(): Promise<void> {
    return Promise.resolve();
  }

  delete(): Promise<void> {
    return Promise.resolve();
  }

  findOne(): Promise<UserBlock | null> {
    return Promise.resolve(null);
  }

  findBidirectional(): Promise<UserBlock | null> {
    return Promise.resolve(null);
  }

  filterBlocked(): Promise<Set<string>> {
    return Promise.resolve(new Set<string>());
  }

  listInitiatedBy(): Promise<{ rows: UserBlock[]; nextCursor: string | null }> {
    return Promise.resolve({ rows: [], nextCursor: null });
  }
}

describe('CascadeUserBlocksOnUserDeletionUseCase', () => {
  it('delegates to repo.deleteAllForUser with the supplied userId', async () => {
    const repo = new FakeUserBlockRepository();
    const useCase = new CascadeUserBlocksOnUserDeletionUseCase(repo);
    const userId = createId();

    await useCase.execute({ userId }, TEST_TX);

    expect(repo.deleteAllForUserCalls).toHaveLength(1);
    expect(repo.deleteAllForUserCalls[0]?.userId).toBe(userId);
  });

  it('passes the caller-supplied TxContext directly to the repo without opening a new UoW (A7 exception)', async () => {
    const repo = new FakeUserBlockRepository();
    const useCase = new CascadeUserBlocksOnUserDeletionUseCase(repo);

    await useCase.execute({ userId: createId() }, TEST_TX);

    expect(repo.deleteAllForUserCalls[0]?.ctx).toBe(TEST_TX);
  });

  it('returns void regardless of how many rows the repo deleted', async () => {
    const repo = new FakeUserBlockRepository();
    repo.deleteAllForUserResult = 5;
    const useCase = new CascadeUserBlocksOnUserDeletionUseCase(repo);

    const result = await useCase.execute({ userId: createId() }, TEST_TX);

    expect(result).toBeUndefined();
  });
});
