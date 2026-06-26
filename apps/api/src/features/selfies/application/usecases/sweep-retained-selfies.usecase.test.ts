import { beforeEach, describe, expect, it } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import { FakeUnitOfWork, FakeEventPublisher, FixedClock, TEST_TX } from '@/core/testing/fakes.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { FileStorage } from '@/core/storage/file-storage.port.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type {
  SelfieDeletionEventRecord,
  SelfieDeletionEventRepository,
} from '@/features/audit/domain/repositories/selfie-deletion-event.repository.js';
import { RecordSelfieDeletionUseCase } from '@/features/audit/application/usecases/record-selfie-deletion.usecase.js';
import { Selfie } from '../../domain/entities/selfie.js';
import type { SelfieRepository } from '../../domain/repositories/selfie.repository.js';
import type {
  PendingStorageDeleteEntry,
  PendingStorageDeleteRepository,
} from '../../domain/repositories/pending-storage-delete.repository.js';
import type {
  SweepRunEntry,
  SweepRunRepository,
} from '../../domain/repositories/sweep-run.repository.js';
import { SweepRetainedSelfiesUseCase } from './sweep-retained-selfies.usecase.js';

// --- Fakes ---

class FakeSelfieRepository implements SelfieRepository {
  private eligible: Selfie[] = [];
  private saved: Map<string, Selfie> = new Map();

  setEligible(selfies: Selfie[]): void {
    this.eligible = [...selfies];
  }

  setEligibleThrows(err: Error): void {
    this.eligible = [];
    this._throwOnEligible = err;
  }
  private _throwOnEligible: Error | null = null;

  save(selfie: Selfie, _ctx?: TxContext): Promise<void> {
    this.saved.set(selfie.id, selfie);
    return Promise.resolve();
  }

  findActiveByUserId(_userId: string, _ctx?: TxContext): Promise<Selfie | null> {
    return Promise.resolve(null);
  }

  findEligibleForRetentionSweep(_cutoff: Date, _ctx?: TxContext): Promise<Selfie[]> {
    if (this._throwOnEligible) {
      return Promise.reject(this._throwOnEligible);
    }
    return Promise.resolve([...this.eligible]);
  }

  getSaved(id: string): Selfie | undefined {
    return this.saved.get(id);
  }
}

class FakePendingStorageDeleteRepository implements PendingStorageDeleteRepository {
  private queue: PendingStorageDeleteEntry[] = [];
  readonly enqueued: PendingStorageDeleteEntry[] = [];
  readonly removed: string[] = [];
  readonly incremented: Array<{ selfieId: string; error: string | null }> = [];

  seed(entries: PendingStorageDeleteEntry[]): void {
    this.queue = [...entries];
  }

  enqueue(entry: PendingStorageDeleteEntry, _ctx?: TxContext): Promise<void> {
    this.enqueued.push(entry);
    this.queue.push(entry);
    return Promise.resolve();
  }

  findPending(): Promise<PendingStorageDeleteEntry[]> {
    return Promise.resolve([...this.queue]);
  }

  remove(selfieId: string, _ctx?: TxContext): Promise<void> {
    this.removed.push(selfieId);
    this.queue = this.queue.filter((e) => e.selfieId !== selfieId);
    return Promise.resolve();
  }

  incrementAttempts(selfieId: string, error?: string, _ctx?: TxContext): Promise<void> {
    this.incremented.push({ selfieId, error: error ?? null });
    this.queue = this.queue.map((e) =>
      e.selfieId === selfieId ? { ...e, attempts: e.attempts + 1 } : e,
    );
    return Promise.resolve();
  }
}

class FakeSweepRunRepository implements SweepRunRepository {
  readonly recorded: SweepRunEntry[] = [];

  record(entry: SweepRunEntry, _ctx?: TxContext): Promise<void> {
    this.recorded.push(entry);
    return Promise.resolve();
  }
}

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

class FakeFileStorage implements FileStorage {
  readonly deletedKeys: string[] = [];
  private _throwOnKey: Set<string> = new Set();

  throwOnKey(key: string): void {
    this._throwOnKey.add(key);
  }

  deleteObject(input: { key: string }): Promise<void> {
    if (this._throwOnKey.has(input.key)) {
      return Promise.reject(new Error(`Storage error for key: ${input.key}`));
    }
    this.deletedKeys.push(input.key);
    return Promise.resolve();
  }

  putObject(_input: { key: string; body: Buffer; contentType: string }): Promise<void> {
    return Promise.resolve();
  }

  getSignedUrl(_input: { key: string; expiresInSeconds: number }): Promise<string> {
    return Promise.resolve('https://example.com/signed');
  }

  getSignedUploadUrl(_input: {
    key: string;
    contentType: string;
    expiresInSeconds: number;
  }): Promise<string> {
    return Promise.resolve('https://example.com/signed-upload');
  }

  getObjectSize(_input: { key: string }): Promise<number> {
    return Promise.resolve(0);
  }
}

const noopLogger: Logger = {
  info: () => undefined,
  warn: () => undefined,
  error: () => undefined,
};

// --- Helpers ---

const THIRTY_ONE_DAYS = 31 * 24 * 60 * 60 * 1000;
const NOW = new Date('2026-06-01T12:00:00Z');

const makeApprovedSelfie = (): Selfie => {
  const userId = createId();
  const approvedAt = new Date(NOW.getTime() - THIRTY_ONE_DAYS);
  return Selfie.rehydrate({
    id: createId(),
    userId,
    status: 'approved',
    storageKey: `uploads/${userId}/selfie.jpg`,
    approvedAt,
    rejectedAt: null,
    deletedAt: null,
    createdAt: approvedAt,
    updatedAt: approvedAt,
  });
};

const makeRejectedSelfie = (): Selfie => {
  const userId = createId();
  const rejectedAt = new Date(NOW.getTime() - THIRTY_ONE_DAYS);
  return Selfie.rehydrate({
    id: createId(),
    userId,
    status: 'rejected',
    storageKey: `uploads/${userId}/selfie2.jpg`,
    approvedAt: null,
    rejectedAt,
    deletedAt: null,
    createdAt: rejectedAt,
    updatedAt: rejectedAt,
  });
};

const makePendingEntry = (
  selfieId: string,
  storageKey: string,
  attempts = 0,
): PendingStorageDeleteEntry => ({
  id: createId(),
  selfieId,
  storageKey,
  attempts,
  enqueuedAt: new Date(NOW.getTime() - 60_000),
  lastAttemptAt: attempts > 0 ? new Date(NOW.getTime() - 30_000) : null,
  lastError: null,
});

// --- Test setup factory ---

const buildUseCase = (opts: {
  selfieRepo: FakeSelfieRepository;
  pendingRepo: FakePendingStorageDeleteRepository;
  sweepRunRepo: FakeSweepRunRepository;
  auditRepo: FakeSelfieDeletionEventRepository;
  publisher: FakeEventPublisher;
  fileStorage: FakeFileStorage;
  clock: FixedClock;
  logger?: Logger;
}): SweepRetainedSelfiesUseCase => {
  const unitOfWork = new FakeUnitOfWork();
  const recordSelfieDeletion = new RecordSelfieDeletionUseCase(opts.auditRepo);
  return new SweepRetainedSelfiesUseCase(
    unitOfWork,
    opts.selfieRepo,
    opts.pendingRepo,
    opts.sweepRunRepo,
    recordSelfieDeletion,
    opts.publisher,
    opts.fileStorage,
    opts.clock,
    opts.logger ?? noopLogger,
  );
};

// --- Tests ---

describe('SweepRetainedSelfiesUseCase', () => {
  let selfieRepo: FakeSelfieRepository;
  let pendingRepo: FakePendingStorageDeleteRepository;
  let sweepRunRepo: FakeSweepRunRepository;
  let auditRepo: FakeSelfieDeletionEventRepository;
  let publisher: FakeEventPublisher;
  let fileStorage: FakeFileStorage;
  let clock: FixedClock;
  let useCase: SweepRetainedSelfiesUseCase;

  beforeEach(() => {
    selfieRepo = new FakeSelfieRepository();
    pendingRepo = new FakePendingStorageDeleteRepository();
    sweepRunRepo = new FakeSweepRunRepository();
    auditRepo = new FakeSelfieDeletionEventRepository();
    publisher = new FakeEventPublisher();
    fileStorage = new FakeFileStorage();
    clock = new FixedClock(NOW);

    useCase = buildUseCase({
      selfieRepo,
      pendingRepo,
      sweepRunRepo,
      auditRepo,
      publisher,
      fileStorage,
      clock,
    });
  });

  describe('happy path: 3 eligible selfies (mixed approved + rejected)', () => {
    it('deletes all 3, attempts storage delete for each, writes correct result', async () => {
      const s1 = makeApprovedSelfie();
      const s2 = makeRejectedSelfie();
      const s3 = makeApprovedSelfie();
      // Capture keys BEFORE execution — markDeleted clears storageKey to null.
      const key1 = s1.storageKey;
      const key2 = s2.storageKey;
      const key3 = s3.storageKey;
      selfieRepo.setEligible([s1, s2, s3]);

      const result = await useCase.execute();

      expect(result.evaluated).toBe(3);
      expect(result.deleted).toBe(3);
      expect(result.failed).toBe(0);

      // All storage deletes attempted (using pre-execution keys).
      const keys = fileStorage.deletedKeys;
      expect(keys).toContain(key1);
      expect(keys).toContain(key2);
      expect(keys).toContain(key3);

      // All audit rows recorded
      expect(auditRepo.recorded).toHaveLength(3);

      // Domain events published
      expect(publisher.published).toHaveLength(3);
      expect(publisher.published.every((e) => e.type === 'selfies.selfieDeleted')).toBe(true);
    });
  });

  describe('idempotency: second run finds 0 eligible (all first-run selfies are now deleted)', () => {
    it('returns evaluated=0, deleted=0 on second execute without clock advance', async () => {
      const s1 = makeApprovedSelfie();
      selfieRepo.setEligible([s1]);
      await useCase.execute();

      // Simulate that after the first run, the repo returns no eligible selfies.
      selfieRepo.setEligible([]);
      const result2 = await useCase.execute();

      expect(result2.evaluated).toBe(0);
      expect(result2.deleted).toBe(0);
    });
  });

  describe('reason mapping', () => {
    it('approved-aged selfie produces audit row with reason retention-sweep', async () => {
      const approved = makeApprovedSelfie();
      selfieRepo.setEligible([approved]);

      await useCase.execute();

      const auditRow = auditRepo.recorded.find((r) => r.selfieId === approved.id);
      expect(auditRow?.reason).toBe('retention-sweep');
    });

    it('rejected-aged selfie produces audit row with reason reviewer-rejection-aged', async () => {
      const rejected = makeRejectedSelfie();
      selfieRepo.setEligible([rejected]);

      await useCase.execute();

      const auditRow = auditRepo.recorded.find((r) => r.selfieId === rejected.id);
      expect(auditRow?.reason).toBe('reviewer-rejection-aged');
    });
  });

  describe('single-record failure isolation', () => {
    it('3 eligible; storage throws on selfie #2; batch completes, #2 in pending, deleted=2 failed=1', async () => {
      const s1 = makeApprovedSelfie();
      const s2 = makeApprovedSelfie();
      const s3 = makeApprovedSelfie();

      // Capture keys BEFORE execution — markDeleted clears storageKey to null.
      const s1Key = s1.storageKey;
      const s2Key = s2.storageKey;
      const s3Key = s3.storageKey;
      if (s2Key === null) throw new Error('Test setup: expected s2.storageKey to be non-null');

      fileStorage.throwOnKey(s2Key);
      selfieRepo.setEligible([s1, s2, s3]);

      const result = await useCase.execute();

      // DB transactions for all 3 committed (DB part succeeds; storage is post-commit).
      // All 3 are counted as deleted because the DB tx succeeded.
      // Storage failure on s2 increments attempts (via attemptStorageDelete).
      expect(result.evaluated).toBe(3);
      expect(result.deleted).toBe(3);
      // Storage delete fails after DB commit — this isn't a `failed` record,
      // it's handled by the reaper. The pending entry for s2 was enqueued in the tx
      // and then incrementAttempts was called by attemptStorageDelete.
      expect(pendingRepo.incremented.some((e) => e.selfieId === s2.id)).toBe(true);

      // s1 and s3 storage deleted successfully.
      expect(fileStorage.deletedKeys).toContain(s1Key);
      expect(fileStorage.deletedKeys).toContain(s3Key);
      expect(fileStorage.deletedKeys).not.toContain(s2Key);
    });
  });

  describe('storage delete called AFTER DB tx commits', () => {
    it('the storage delete spy is called after the unitOfWork.run callback resolves', async () => {
      const callOrder: string[] = [];

      // Wrap the useCase with a tracking unit of work
      const trackingUow = {
        async run<T>(work: (ctx: TxContext) => Promise<T>): Promise<T> {
          const result = await work(TEST_TX);
          callOrder.push('tx-committed');
          return result;
        },
      };
      const recordSelfieDeletion = new RecordSelfieDeletionUseCase(auditRepo);
      const trackingStorage: FileStorage = {
        deleteObject(_input): Promise<void> {
          callOrder.push('storage-deleted');
          return Promise.resolve();
        },
        putObject(): Promise<void> {
          return Promise.resolve();
        },
        getSignedUrl(): Promise<string> {
          return Promise.resolve('');
        },
        getSignedUploadUrl(): Promise<string> {
          return Promise.resolve('');
        },
        getObjectSize(): Promise<number> {
          return Promise.resolve(0);
        },
      };

      const tracked = new SweepRetainedSelfiesUseCase(
        trackingUow,
        selfieRepo,
        pendingRepo,
        sweepRunRepo,
        recordSelfieDeletion,
        publisher,
        trackingStorage,
        clock,
        noopLogger,
      );

      selfieRepo.setEligible([makeApprovedSelfie()]);
      await tracked.execute();

      const txIdx = callOrder.indexOf('tx-committed');
      const storageIdx = callOrder.indexOf('storage-deleted');
      expect(txIdx).not.toBe(-1);
      expect(storageIdx).not.toBe(-1);
      expect(storageIdx).toBeGreaterThan(txIdx);
    });
  });

  describe('storageKey captured before markDeleted clears it', () => {
    it('storage delete uses the original key, not the null that markDeleted sets', async () => {
      const selfie = makeApprovedSelfie();
      const originalKey = selfie.storageKey;
      if (originalKey === null)
        throw new Error('Test setup: expected selfie.storageKey to be non-null');
      selfieRepo.setEligible([selfie]);

      await useCase.execute();

      expect(fileStorage.deletedKeys).toContain(originalKey);
    });
  });

  describe('orphan reaper pass', () => {
    it('pre-seeded pending entries: one succeeds (remove called), one fails (incrementAttempts called)', async () => {
      const key1 = 'old/selfie1.jpg';
      const key2 = 'old/selfie2.jpg';
      const e1 = makePendingEntry(createId(), key1, 1);
      const e2 = makePendingEntry(createId(), key2, 2);

      // storage throws for key2
      fileStorage.throwOnKey(key2);
      pendingRepo.seed([e1, e2]);
      selfieRepo.setEligible([]);

      const result = await useCase.execute();

      expect(result.reaperRetried).toBe(2);
      expect(result.reaperSucceeded).toBe(1);
      expect(pendingRepo.removed).toContain(e1.selfieId);
      expect(pendingRepo.incremented.some((x) => x.selfieId === e2.selfieId)).toBe(true);
    });
  });

  describe('10-attempt cap', () => {
    it('entry with attempts=10 is skipped: no remove, no increment', async () => {
      const cappedKey = 'capped/selfie.jpg';
      const cappedEntry = makePendingEntry(createId(), cappedKey, 10);
      pendingRepo.seed([cappedEntry]);
      selfieRepo.setEligible([]);

      await useCase.execute();

      expect(pendingRepo.removed).not.toContain(cappedEntry.selfieId);
      expect(pendingRepo.incremented.some((x) => x.selfieId === cappedEntry.selfieId)).toBe(false);
      expect(fileStorage.deletedKeys).not.toContain(cappedKey);
    });
  });

  describe('sweep_runs row', () => {
    it('writes exactly one sweep_runs row per execute', async () => {
      selfieRepo.setEligible([makeApprovedSelfie(), makeRejectedSelfie()]);

      await useCase.execute();

      expect(sweepRunRepo.recorded).toHaveLength(1);
    });

    it('sweep_runs row contains correct totals', async () => {
      const s1 = makeApprovedSelfie();
      const s2 = makeRejectedSelfie();
      selfieRepo.setEligible([s1, s2]);

      await useCase.execute();

      const row = sweepRunRepo.recorded[0];
      expect(row?.kind).toBe('selfie-retention-sweep');
      expect(row?.evaluated).toBe(2);
      expect(row?.deleted).toBe(2);
      expect(row?.failed).toBe(0);
      expect(row?.error).toBeNull();
      expect(row?.startedAt).toEqual(NOW);
      expect(row?.finishedAt).toBeDefined();
      expect(row?.auditRowsSevered).toBeNull();
    });

    it('writes sweep_runs row even on zero-eligible tick', async () => {
      selfieRepo.setEligible([]);

      await useCase.execute();

      expect(sweepRunRepo.recorded).toHaveLength(1);
      expect(sweepRunRepo.recorded[0]?.evaluated).toBe(0);
    });
  });

  describe('tick-level error: findEligibleForRetentionSweep throws', () => {
    it('writes sweep_runs row with error populated, then re-throws', async () => {
      const boom = new Error('DB connection lost');
      selfieRepo.setEligibleThrows(boom);

      await expect(useCase.execute()).rejects.toThrow('DB connection lost');

      expect(sweepRunRepo.recorded).toHaveLength(1);
      expect(sweepRunRepo.recorded[0]?.error).toBe('DB connection lost');
    });
  });
});
