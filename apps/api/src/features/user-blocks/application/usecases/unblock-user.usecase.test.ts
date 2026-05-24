import { describe, expect, it } from 'vitest';
import { FakeEventPublisher, FakeUnitOfWork, FixedClock } from '@/core/testing/fakes.js';
import { UserBlock } from '../../domain/entities/user-block.js';
import { USER_UNBLOCKED } from '../../domain/events/user-unblocked.event.js';
import type { UserBlockRepository } from '../../domain/repositories/user-block.repository.js';
import { UnblockUserUseCase } from './unblock-user.usecase.js';

const NOW = new Date('2026-05-19T10:00:00Z');

class FakeUserBlockRepository implements UserBlockRepository {
  private readonly blocks = new Map<string, UserBlock>();

  seed(block: UserBlock): void {
    this.blocks.set(`${block.initiatorUserId}:${block.blockedUserId}`, block);
  }

  save(block: UserBlock): Promise<void> {
    this.blocks.set(`${block.initiatorUserId}:${block.blockedUserId}`, block);
    return Promise.resolve();
  }

  delete(input: { initiatorUserId: string; blockedUserId: string }): Promise<void> {
    this.blocks.delete(`${input.initiatorUserId}:${input.blockedUserId}`);
    return Promise.resolve();
  }

  findOne(input: { initiatorUserId: string; blockedUserId: string }): Promise<UserBlock | null> {
    return Promise.resolve(
      this.blocks.get(`${input.initiatorUserId}:${input.blockedUserId}`) ?? null,
    );
  }

  findBidirectional(input: { userA: string; userB: string }): Promise<UserBlock | null> {
    return Promise.resolve(
      this.blocks.get(`${input.userA}:${input.userB}`) ??
        this.blocks.get(`${input.userB}:${input.userA}`) ??
        null,
    );
  }

  filterBlocked(): Promise<Set<string>> {
    return Promise.resolve(new Set<string>());
  }

  listInitiatedBy(): Promise<{ rows: UserBlock[]; nextCursor: string | null }> {
    return Promise.resolve({ rows: [], nextCursor: null });
  }

  deleteAllForUser(_userId: string, _ctx: unknown): Promise<number> {
    return Promise.resolve(0);
  }
}

describe('UnblockUserUseCase', () => {
  it('records userUnblocked event, publishes, and deletes the row', async () => {
    const repo = new FakeUserBlockRepository();
    const existingBlock = UserBlock.rehydrate({
      id: 'block-1',
      initiatorUserId: 'user-A',
      blockedUserId: 'user-B',
      createdAt: new Date('2026-05-18T09:00:00Z'),
    });
    repo.seed(existingBlock);

    const publisher = new FakeEventPublisher();
    const useCase = new UnblockUserUseCase(
      new FakeUnitOfWork(),
      repo,
      publisher,
      new FixedClock(NOW),
    );

    await useCase.execute({ initiatorUserId: 'user-A', blockedUserId: 'user-B' });

    expect(publisher.published.some((e) => e.type === USER_UNBLOCKED)).toBe(true);

    // Row should be deleted.
    const found = await repo.findOne({ initiatorUserId: 'user-A', blockedUserId: 'user-B' });
    expect(found).toBeNull();
  });

  it('is a silent no-op when no block exists', async () => {
    const repo = new FakeUserBlockRepository();
    const publisher = new FakeEventPublisher();
    let uowCalled = false;
    const wrappedUow = {
      run: async <T>(
        work: (ctx: import('@/core/db/unit-of-work.port.js').TxContext) => Promise<T>,
      ): Promise<T> => {
        uowCalled = true;
        const uow = new FakeUnitOfWork();
        return uow.run(work);
      },
    };

    const useCase = new UnblockUserUseCase(wrappedUow, repo, publisher, new FixedClock(NOW));

    await useCase.execute({ initiatorUserId: 'user-A', blockedUserId: 'user-B' });

    expect(uowCalled).toBe(false);
    expect(publisher.published).toHaveLength(0);
  });
});
