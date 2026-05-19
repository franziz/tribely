import { beforeEach, describe, expect, it } from 'vitest';
import { runWithContext } from '@/core/context/request-context.js';
import { runAsSystem } from '@/core/context/system-context.js';
import { sha256Hex } from '@/core/crypto/sha256-hex.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { TEST_TX } from '@/core/testing/fakes.js';
import type {
  AccountDeletionCascadeScope,
  AccountDeletionEventRecord,
  AccountDeletionEventRepository,
} from '../../domain/repositories/account-deletion-event.repository.js';
import { RecordAccountDeletionUseCase } from './record-account-deletion.usecase.js';

class FakeAccountDeletionEventRepository implements AccountDeletionEventRepository {
  readonly recorded: AccountDeletionEventRecord[] = [];
  record(entry: AccountDeletionEventRecord, _ctx: TxContext): Promise<void> {
    this.recorded.push(entry);
    return Promise.resolve();
  }
}

describe('RecordAccountDeletionUseCase', () => {
  let repo: FakeAccountDeletionEventRepository;
  let useCase: RecordAccountDeletionUseCase;

  const INPUT = {
    userId: 'user_test_1',
    requestedAt: new Date('2026-05-19T10:00:00Z'),
    completedAt: new Date('2026-05-19T10:00:01Z'),
    cascadeScope: ['users', 'credentials', 'refresh_tokens'] as AccountDeletionCascadeScope[],
    outcome: 'completed' as const,
    failureReason: null,
  };

  beforeEach(() => {
    repo = new FakeAccountDeletionEventRepository();
    useCase = new RecordAccountDeletionUseCase(repo);
  });

  it('(a) captures requestId from an active HTTP-style context frame', async () => {
    await runWithContext({ requestId: 'req-001', actorUserId: 'user_test_1' }, async () => {
      await useCase.execute(INPUT, TEST_TX);
    });

    expect(repo.recorded).toHaveLength(1);
    expect(repo.recorded[0]?.requestId).toBe('req-001');
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

  it('hashes userId with SHA-256 (non-reversible pseudonymisation)', async () => {
    await useCase.execute(INPUT, TEST_TX);

    const record = repo.recorded[0];
    expect(record?.userIdHash).toBe(sha256Hex('user_test_1'));
    // Must NOT store plaintext userId
    expect(record).not.toHaveProperty('userId');
    // Hash is a 64-char hex string
    expect(record?.userIdHash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('persists all input fields correctly', async () => {
    await runWithContext({ requestId: 'req-fields', actorUserId: null }, async () => {
      await useCase.execute(INPUT, TEST_TX);
    });

    const record = repo.recorded[0];
    expect(record?.requestedAt).toEqual(INPUT.requestedAt);
    expect(record?.completedAt).toEqual(INPUT.completedAt);
    expect(record?.cascadeScope).toEqual(['users', 'credentials', 'refresh_tokens']);
    expect(record?.outcome).toBe('completed');
    expect(record?.failureReason).toBeNull();
    expect(record?.id).toMatch(/^[a-z0-9]{8,}$/i);
    expect(record?.recordedAt).toBeInstanceOf(Date);
  });

  it('persists failureReason when outcome is failed_rolled_back', async () => {
    const failInput = {
      ...INPUT,
      outcome: 'failed_rolled_back' as const,
      failureReason: 'constraint violation on events table',
    };

    await useCase.execute(failInput, TEST_TX);

    const record = repo.recorded[0];
    expect(record?.outcome).toBe('failed_rolled_back');
    expect(record?.failureReason).toBe('constraint violation on events table');
  });

  it('passes the supplied TxContext through to the repository', async () => {
    const contexts: TxContext[] = [];
    const capturingRepo: AccountDeletionEventRepository = {
      record(_entry, ctx) {
        contexts.push(ctx);
        return Promise.resolve();
      },
    };
    const sut = new RecordAccountDeletionUseCase(capturingRepo);

    await sut.execute(INPUT, TEST_TX);

    expect(contexts).toHaveLength(1);
    expect(contexts[0]).toBe(TEST_TX);
  });
});
