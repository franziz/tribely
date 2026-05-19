import { beforeEach, describe, expect, it } from 'vitest';
import { runWithContext } from '@/core/context/request-context.js';
import { runAsSystem } from '@/core/context/system-context.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { TEST_TX } from '@/core/testing/fakes.js';
import type {
  SelfieDeletionEventRecord,
  SelfieDeletionEventRepository,
} from '../../domain/repositories/selfie-deletion-event.repository.js';
import { RecordSelfieDeletionUseCase } from './record-selfie-deletion.usecase.js';

class FakeSelfieDeletionEventRepository implements SelfieDeletionEventRepository {
  readonly recorded: SelfieDeletionEventRecord[] = [];
  record(entry: SelfieDeletionEventRecord, _ctx: TxContext): Promise<void> {
    this.recorded.push(entry);
    return Promise.resolve();
  }
  pruneOlderThan(_cutoff: Date, _ctx: TxContext): Promise<number> {
    return Promise.resolve(0);
  }
}

describe('RecordSelfieDeletionUseCase', () => {
  let repo: FakeSelfieDeletionEventRepository;
  let useCase: RecordSelfieDeletionUseCase;

  const INPUT = {
    userId: 'u_1',
    selfieId: 'selfie_1',
    reason: 'user-request' as const,
    deletedAt: new Date('2026-05-19T10:00:00Z'),
  };

  beforeEach(() => {
    repo = new FakeSelfieDeletionEventRepository();
    useCase = new RecordSelfieDeletionUseCase(repo);
  });

  it('(a) captures requestId from an active HTTP-style context frame', async () => {
    await runWithContext({ requestId: 'req-001', actorUserId: 'u1' }, async () => {
      await useCase.execute(INPUT, TEST_TX);
    });

    expect(repo.recorded).toHaveLength(1);
    expect(repo.recorded[0]?.requestId).toBe('req-001');
    expect(repo.recorded[0]?.userId).toBe('u_1');
    expect(repo.recorded[0]?.selfieId).toBe('selfie_1');
    expect(repo.recorded[0]?.reason).toBe('user-request');
    expect(repo.recorded[0]?.deletedAt).toEqual(INPUT.deletedAt);
    expect(repo.recorded[0]?.id).toMatch(/^[a-z0-9]{8,}$/i);
  });

  it('(b) records requestId as null when called outside any ALS frame', async () => {
    // Call with no enclosing runWithContext / runAsSystem
    await useCase.execute(INPUT, TEST_TX);

    expect(repo.recorded).toHaveLength(1);
    expect(repo.recorded[0]?.requestId).toBeNull();
  });

  it('(c) captures the system: requestId when wrapped in runAsSystem', async () => {
    await runAsSystem('cron.test', async () => {
      await useCase.execute(INPUT, TEST_TX);
    });

    expect(repo.recorded).toHaveLength(1);
    expect(repo.recorded[0]?.requestId).toMatch(/^system:cron\.test:/);
  });

  it('passes the supplied TxContext through to the repository', async () => {
    const contexts: TxContext[] = [];
    const capturingRepo: SelfieDeletionEventRepository = {
      record(entry, ctx) {
        contexts.push(ctx);
        return Promise.resolve();
      },
      pruneOlderThan: () => Promise.resolve(0),
    };
    const sut = new RecordSelfieDeletionUseCase(capturingRepo);

    await sut.execute(INPUT, TEST_TX);

    expect(contexts).toHaveLength(1);
    expect(contexts[0]).toBe(TEST_TX);
  });
});
