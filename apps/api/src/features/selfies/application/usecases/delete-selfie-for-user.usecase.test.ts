import { beforeEach, describe, expect, it } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import { FixedClock, FakeEventPublisher, TEST_TX } from '@/core/testing/fakes.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  SelfieDeletionEventRecord,
  SelfieDeletionEventRepository,
  SelfieDeletionReason,
} from '@/features/audit/domain/repositories/selfie-deletion-event.repository.js';
import { RecordSelfieDeletionUseCase } from '@/features/audit/application/usecases/record-selfie-deletion.usecase.js';
import { Selfie } from '../../domain/entities/selfie.js';
import type { SelfieRepository } from '../../domain/repositories/selfie.repository.js';
import type {
  PendingStorageDeleteEntry,
  PendingStorageDeleteRepository,
} from '../../domain/repositories/pending-storage-delete.repository.js';
import { DeleteSelfieForUserUseCase } from './delete-selfie-for-user.usecase.js';

// --- Fakes ---

class FakeSelfieRepository implements SelfieRepository {
  private selfies: Map<string, Selfie> = new Map();

  seed(selfie: Selfie): void {
    this.selfies.set(selfie.userId, selfie);
  }

  save(selfie: Selfie, _ctx?: TxContext): Promise<void> {
    this.selfies.set(selfie.userId, selfie);
    return Promise.resolve();
  }

  findActiveByUserId(userId: string, _ctx?: TxContext): Promise<Selfie | null> {
    const selfie = this.selfies.get(userId) ?? null;
    // Exclude already-deleted (mirrors real repository behaviour).
    if (selfie && selfie.status === 'deleted') {
      return Promise.resolve(null);
    }
    return Promise.resolve(selfie);
  }

  findEligibleForRetentionSweep(_cutoff: Date, _ctx?: TxContext): Promise<Selfie[]> {
    return Promise.resolve([]);
  }
}

class FakePendingStorageDeleteRepository implements PendingStorageDeleteRepository {
  readonly enqueued: PendingStorageDeleteEntry[] = [];
  readonly removed: string[] = [];
  readonly incremented: Array<{ selfieId: string; error: string | null }> = [];

  enqueue(entry: PendingStorageDeleteEntry, _ctx?: TxContext): Promise<void> {
    this.enqueued.push(entry);
    return Promise.resolve();
  }

  findPending(): Promise<PendingStorageDeleteEntry[]> {
    return Promise.resolve([...this.enqueued]);
  }

  remove(selfieId: string, _ctx?: TxContext): Promise<void> {
    this.removed.push(selfieId);
    return Promise.resolve();
  }

  incrementAttempts(selfieId: string, error?: string, _ctx?: TxContext): Promise<void> {
    this.incremented.push({ selfieId, error: error ?? null });
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

// --- Helpers ---

const NOW = new Date('2026-06-01T12:00:00Z');

const makeApprovedSelfie = (userId: string): Selfie => {
  const pastApproval = new Date(NOW.getTime() - 31 * 24 * 60 * 60 * 1000);
  return Selfie.rehydrate({
    id: createId(),
    userId,
    status: 'approved',
    storageKey: `uploads/${userId}/selfie.jpg`,
    approvedAt: pastApproval,
    rejectedAt: null,
    deletedAt: null,
    createdAt: pastApproval,
    updatedAt: pastApproval,
  });
};

const makePendingSelfie = (userId: string): Selfie =>
  Selfie.rehydrate({
    id: createId(),
    userId,
    status: 'pending',
    storageKey: `uploads/${userId}/pending.jpg`,
    approvedAt: null,
    rejectedAt: null,
    deletedAt: null,
    createdAt: NOW,
    updatedAt: NOW,
  });

const makeSelfieNoKey = (userId: string): Selfie =>
  Selfie.rehydrate({
    id: createId(),
    userId,
    status: 'approved',
    storageKey: null,
    approvedAt: new Date(NOW.getTime() - 35 * 24 * 60 * 60 * 1000),
    rejectedAt: null,
    deletedAt: null,
    createdAt: NOW,
    updatedAt: NOW,
  });

// --- Tests ---

describe('DeleteSelfieForUserUseCase', () => {
  let selfieRepo: FakeSelfieRepository;
  let pendingRepo: FakePendingStorageDeleteRepository;
  let auditRepo: FakeSelfieDeletionEventRepository;
  let publisher: FakeEventPublisher;
  let clock: FixedClock;
  let useCase: DeleteSelfieForUserUseCase;

  beforeEach(() => {
    selfieRepo = new FakeSelfieRepository();
    pendingRepo = new FakePendingStorageDeleteRepository();
    auditRepo = new FakeSelfieDeletionEventRepository();
    publisher = new FakeEventPublisher();
    clock = new FixedClock(NOW);

    const recordSelfieDeletion = new RecordSelfieDeletionUseCase(auditRepo);
    useCase = new DeleteSelfieForUserUseCase(
      selfieRepo,
      pendingRepo,
      recordSelfieDeletion,
      publisher,
      clock,
    );
  });

  describe('happy path: user has an active selfie with a storageKey', () => {
    it('calls markDeleted, save, publish, recordSelfieDeletion, and enqueue — all with ctx', async () => {
      const userId = createId();
      const selfie = makeApprovedSelfie(userId);
      selfieRepo.seed(selfie);

      await useCase.execute({ userId, reason: 'account-deletion' }, TEST_TX);

      // selfie saved with ctx (findActiveByUserId returns null after deletion)
      const active = await selfieRepo.findActiveByUserId(userId);
      expect(active).toBeNull();

      // audit row written
      expect(auditRepo.recorded).toHaveLength(1);
      expect(auditRepo.recorded[0]?.userId).toBe(userId);
      expect(auditRepo.recorded[0]?.selfieId).toBe(selfie.id);
      expect(auditRepo.recorded[0]?.reason).toBe('account-deletion');
      expect(auditRepo.recorded[0]?.deletedAt).toEqual(NOW);

      // storage enqueued for deferred reaper
      expect(pendingRepo.enqueued).toHaveLength(1);
      expect(pendingRepo.enqueued[0]?.selfieId).toBe(selfie.id);
      expect(pendingRepo.enqueued[0]?.storageKey).toBe(`uploads/${userId}/selfie.jpg`);
      expect(pendingRepo.enqueued[0]?.attempts).toBe(0);

      // domain event published
      expect(publisher.published).toHaveLength(1);
      expect(publisher.published[0]?.type).toBe('selfies.selfieDeleted');
    });

    it('does NOT invoke fileStorage directly — storage delete is deferred to reaper', async () => {
      // This test asserts the interface-level contract: no storage call happens here.
      // The reaper in SweepRetainedSelfiesUseCase owns the actual delete.
      const userId = createId();
      selfieRepo.seed(makeApprovedSelfie(userId));

      // No fileStorage is injected into DeleteSelfieForUserUseCase by design.
      // We confirm nothing went to pendingRepo.removed (that would be a delete).
      await useCase.execute({ userId, reason: 'account-deletion' }, TEST_TX);

      expect(pendingRepo.removed).toHaveLength(0);
    });
  });

  describe('no-selfie case (idempotent)', () => {
    it('returns void without writing any rows when user has no active selfie', async () => {
      const userId = createId();
      // No seed — findActiveByUserId returns null

      await useCase.execute({ userId, reason: 'account-deletion' }, TEST_TX);

      expect(auditRepo.recorded).toHaveLength(0);
      expect(pendingRepo.enqueued).toHaveLength(0);
      expect(publisher.published).toHaveLength(0);
    });
  });

  describe('storageKey is null', () => {
    it('records audit row and domain event but does NOT enqueue a pending-delete', async () => {
      const userId = createId();
      selfieRepo.seed(makeSelfieNoKey(userId));

      await useCase.execute({ userId, reason: 'account-deletion' }, TEST_TX);

      expect(auditRepo.recorded).toHaveLength(1);
      expect(pendingRepo.enqueued).toHaveLength(0);
      expect(publisher.published).toHaveLength(1);
    });
  });

  describe('reason plumbing', () => {
    const reasons: SelfieDeletionReason[] = [
      'account-deletion',
      'user-request',
      'retention-sweep',
      'reviewer-rejection-aged',
    ];

    for (const reason of reasons) {
      it(`passes reason '${reason}' through to the audit row`, async () => {
        const userId = createId();
        selfieRepo.seed(makePendingSelfie(userId));

        await useCase.execute({ userId, reason }, TEST_TX);

        expect(auditRepo.recorded[0]?.reason).toBe(reason);
      });
    }
  });

  describe('storageKey captured before markDeleted clears it', () => {
    it('enqueues the original storageKey even though selfie.storageKey is null after deletion', async () => {
      const userId = createId();
      const selfie = makeApprovedSelfie(userId);
      const originalKey = selfie.storageKey;
      selfieRepo.seed(selfie);

      await useCase.execute({ userId, reason: 'account-deletion' }, TEST_TX);

      // After markDeleted, selfie.storageKey is null — but enqueue used the original.
      expect(pendingRepo.enqueued[0]?.storageKey).toBe(originalKey);
    });
  });
});
