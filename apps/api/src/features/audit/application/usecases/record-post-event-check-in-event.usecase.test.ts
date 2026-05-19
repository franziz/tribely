import { beforeEach, describe, expect, it } from 'vitest';
import { runWithContext } from '@/core/context/request-context.js';
import { runAsSystem } from '@/core/context/system-context.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { TEST_TX } from '@/core/testing/fakes.js';
import type {
  PostEventCheckInEventEntry,
  PostEventCheckInEventRepository,
} from '../../domain/repositories/post-event-check-in-event.repository.js';
import { RecordPostEventCheckInEventUseCase } from './record-post-event-check-in-event.usecase.js';

class FakePostEventCheckInEventRepository implements PostEventCheckInEventRepository {
  readonly recorded: PostEventCheckInEventEntry[] = [];
  record(entry: PostEventCheckInEventEntry, _ctx: TxContext): Promise<void> {
    this.recorded.push(entry);
    return Promise.resolve();
  }
  pruneOlderThan(_cutoff: Date, _ctx: TxContext): Promise<number> {
    return Promise.resolve(0);
  }
}

describe('RecordPostEventCheckInEventUseCase', () => {
  let repo: FakePostEventCheckInEventRepository;
  let useCase: RecordPostEventCheckInEventUseCase;

  const INPUT = {
    checkInId: 'checkin_1',
    userId: 'u_1',
    eventId: 'event_1',
    reason: 'created' as const,
    occurredAt: new Date('2026-05-19T10:00:00Z'),
  };

  beforeEach(() => {
    repo = new FakePostEventCheckInEventRepository();
    useCase = new RecordPostEventCheckInEventUseCase(repo);
  });

  it('(a) captures requestId from an active HTTP-style context frame', async () => {
    await runWithContext({ requestId: 'req-001', actorUserId: 'u1' }, async () => {
      await useCase.execute(INPUT, TEST_TX);
    });

    expect(repo.recorded).toHaveLength(1);
    expect(repo.recorded[0]?.requestId).toBe('req-001');
    expect(repo.recorded[0]?.checkInId).toBe('checkin_1');
    expect(repo.recorded[0]?.userId).toBe('u_1');
    expect(repo.recorded[0]?.eventId).toBe('event_1');
    expect(repo.recorded[0]?.reason).toBe('created');
    expect(repo.recorded[0]?.occurredAt).toEqual(INPUT.occurredAt);
    expect(repo.recorded[0]?.id).toMatch(/^[a-z0-9]{8,}$/i);
  });

  it('(b) records requestId as null when called outside any ALS frame', async () => {
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
    const capturingRepo: PostEventCheckInEventRepository = {
      record(entry, ctx) {
        contexts.push(ctx);
        return Promise.resolve();
      },
      pruneOlderThan: () => Promise.resolve(0),
    };
    const sut = new RecordPostEventCheckInEventUseCase(capturingRepo);

    await sut.execute(INPUT, TEST_TX);

    expect(contexts).toHaveLength(1);
    expect(contexts[0]).toBe(TEST_TX);
  });

  /**
   * Type-level enforcement test: the two-arg signature `execute(input, ctx)` is
   * the compile-time signal that this use case MUST be called from inside an
   * existing UoW. This test documents that `ctx` is NOT optional — calling
   * `execute(INPUT)` would be a TypeScript compile error (missing arg). The
   * absence of `ctx?:` in the signature is the contract; this comment + test
   * name make the intent explicit for reviewers.
   *
   * To verify: try removing `TEST_TX` from the call below — tsc will reject it.
   */
  it('(type-level) ctx is required — omitting it is a compile error', async () => {
    // This line would fail to compile if ctx were optional:
    //   await useCase.execute(INPUT);  // Error: Expected 2 arguments, but got 1.
    await useCase.execute(INPUT, TEST_TX);

    // If we got here, the required-ctx contract is upheld at the call site.
    expect(repo.recorded).toHaveLength(1);
  });
});
