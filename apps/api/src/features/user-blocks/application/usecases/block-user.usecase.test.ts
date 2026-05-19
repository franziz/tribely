import { describe, expect, it } from 'vitest';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { FakeEventPublisher, FakeUnitOfWork, FixedClock } from '@/core/testing/fakes.js';
import type { CascadePendingBlocksPort } from '@/features/join-requests/application/ports/cascade-pending-blocks.port.js';
import { UserBlock } from '../../domain/entities/user-block.js';
import { USER_BLOCKED } from '../../domain/events/user-blocked.event.js';
import type { UserBlockRepository } from '../../domain/repositories/user-block.repository.js';
import { BlockUserUseCase } from './block-user.usecase.js';

const NOW = new Date('2026-05-19T10:00:00Z');

class FakeUserBlockRepository implements UserBlockRepository {
  private readonly blocks = new Map<string, UserBlock>();

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
}

class FakeCascadePendingBlocksPort implements CascadePendingBlocksPort {
  calls: Array<{ userA: string; userB: string }> = [];
  cancelPendingAndFutureAcceptedBetween(
    input: { userA: string; userB: string },
    _ctx: TxContext,
  ): Promise<{ cancelledCount: number }> {
    this.calls.push(input);
    return Promise.resolve({ cancelledCount: 0 });
  }
}

describe('BlockUserUseCase', () => {
  it('creates and saves a new block, emits userBlocked, cascades', async () => {
    const repo = new FakeUserBlockRepository();
    const cascade = new FakeCascadePendingBlocksPort();
    const publisher = new FakeEventPublisher();
    const useCase = new BlockUserUseCase(
      new FakeUnitOfWork(),
      repo,
      cascade,
      publisher,
      new FixedClock(NOW),
    );

    const result = await useCase.execute({ initiatorUserId: 'user-A', blockedUserId: 'user-B' });

    expect(result.initiatorUserId).toBe('user-A');
    expect(result.blockedUserId).toBe('user-B');

    const saved = await repo.findOne({ initiatorUserId: 'user-A', blockedUserId: 'user-B' });
    expect(saved).not.toBeNull();

    expect(publisher.published.some((e) => e.type === USER_BLOCKED)).toBe(true);
    expect(cascade.calls).toHaveLength(1);
    expect(cascade.calls[0]).toMatchObject({ userA: 'user-A', userB: 'user-B' });
  });

  it('is idempotent — returns existing block without re-emitting event', async () => {
    const repo = new FakeUserBlockRepository();
    const existingBlock = UserBlock.rehydrate({
      id: 'existing-id',
      initiatorUserId: 'user-A',
      blockedUserId: 'user-B',
      createdAt: NOW,
    });
    await repo.save(existingBlock);

    const cascade = new FakeCascadePendingBlocksPort();
    const publisher = new FakeEventPublisher();
    const uow = new FakeUnitOfWork();
    let uowCalled = false;
    const wrappedUow = {
      run: async <T>(work: (ctx: TxContext) => Promise<T>): Promise<T> => {
        uowCalled = true;
        return uow.run(work);
      },
    };

    const useCase = new BlockUserUseCase(wrappedUow, repo, cascade, publisher, new FixedClock(NOW));

    const result = await useCase.execute({ initiatorUserId: 'user-A', blockedUserId: 'user-B' });

    expect(result.id).toBe('existing-id');
    expect(uowCalled).toBe(false);
    expect(publisher.published).toHaveLength(0);
    expect(cascade.calls).toHaveLength(0);
  });

  it('throws 422 for self-block before any DB access', async () => {
    const repo = new FakeUserBlockRepository();

    // Self-block throws synchronously in UserBlock.initiate before any async
    // repo call — so the cascade / uow are never entered.
    const cascade = new FakeCascadePendingBlocksPort();
    const publisher = new FakeEventPublisher();
    const useCase = new BlockUserUseCase(
      new FakeUnitOfWork(),
      repo,
      cascade,
      publisher,
      new FixedClock(NOW),
    );

    await expect(
      useCase.execute({ initiatorUserId: 'user-A', blockedUserId: 'user-A' }),
    ).rejects.toMatchObject({ status: 422 });

    // No blocks should have been saved and no events published.
    expect(publisher.published).toHaveLength(0);
    expect(cascade.calls).toHaveLength(0);
  });
});
