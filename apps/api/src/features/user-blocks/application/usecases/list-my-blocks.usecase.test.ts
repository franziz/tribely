import { describe, expect, it } from 'vitest';
import { UserBlock } from '../../domain/entities/user-block.js';
import type { UserBlockRepository } from '../../domain/repositories/user-block.repository.js';
import { ListMyBlocksUseCase } from './list-my-blocks.usecase.js';

const NOW = new Date('2026-05-19T10:00:00Z');

const makeBlock = (id: string): UserBlock =>
  UserBlock.rehydrate({
    id,
    initiatorUserId: 'user-A',
    blockedUserId: `user-${id}`,
    createdAt: NOW,
  });

/**
 * Tracking fake that records the last call to `listInitiatedBy` for assertion.
 */
class FakeUserBlockRepository implements UserBlockRepository {
  lastListInput: Parameters<UserBlockRepository['listInitiatedBy']>[0] | undefined = undefined;
  stubbedResult: { rows: UserBlock[]; nextCursor: string | null } = { rows: [], nextCursor: null };

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
  listInitiatedBy(
    input: Parameters<UserBlockRepository['listInitiatedBy']>[0],
  ): Promise<{ rows: UserBlock[]; nextCursor: string | null }> {
    this.lastListInput = input;
    return Promise.resolve(this.stubbedResult);
  }
}

describe('ListMyBlocksUseCase', () => {
  it('delegates to repo with sanitised limit', async () => {
    const repo = new FakeUserBlockRepository();
    repo.stubbedResult = { rows: [makeBlock('b1')], nextCursor: null };
    const useCase = new ListMyBlocksUseCase(repo);

    const result = await useCase.execute({ initiatorUserId: 'user-A', limit: 5 });

    expect(repo.lastListInput).toMatchObject({
      initiatorUserId: 'user-A',
      limit: 5,
    });
    expect(result.rows).toHaveLength(1);
    expect(result.nextCursor).toBeNull();
  });

  it('caps limit at 100', async () => {
    const repo = new FakeUserBlockRepository();
    const useCase = new ListMyBlocksUseCase(repo);

    await useCase.execute({ initiatorUserId: 'user-A', limit: 9999 });

    expect(repo.lastListInput?.limit).toBe(100);
  });

  it('defaults limit to 20 when not provided', async () => {
    const repo = new FakeUserBlockRepository();
    const useCase = new ListMyBlocksUseCase(repo);

    await useCase.execute({ initiatorUserId: 'user-A' });

    expect(repo.lastListInput?.limit).toBe(20);
  });

  it('passes cursor through when provided', async () => {
    const repo = new FakeUserBlockRepository();
    const useCase = new ListMyBlocksUseCase(repo);

    await useCase.execute({ initiatorUserId: 'user-A', cursor: 'some-cursor' });

    expect(repo.lastListInput?.cursor).toBe('some-cursor');
  });
});
