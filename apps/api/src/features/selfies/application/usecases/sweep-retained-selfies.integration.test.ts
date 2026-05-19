// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { runAsSystem } from '@/core/context/system-context.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import { FakeEventPublisher, FixedClock } from '@/core/testing/fakes.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { FileStorage } from '@/core/storage/file-storage.port.js';
import { RecordSelfieDeletionUseCase } from '@/features/audit/application/usecases/record-selfie-deletion.usecase.js';
import { SelfieDeletionEventPrismaRepository } from '@/features/audit/infrastructure/persistence/selfie-deletion-event.prisma-repository.js';
import { Selfie } from '../../domain/entities/selfie.js';
import { SelfiePrismaRepository } from '../../infrastructure/persistence/selfie.prisma-repository.js';
import { PendingStorageDeletePrismaRepository } from '../../infrastructure/persistence/pending-storage-delete.prisma-repository.js';
import { SweepRunPrismaRepository } from '../../infrastructure/persistence/sweep-run.prisma-repository.js';
import { SweepRetainedSelfiesUseCase } from './sweep-retained-selfies.usecase.js';

const dbUrl = process.env.DATABASE_URL;

const noopLogger: Logger = {
  info: () => undefined,
  warn: () => undefined,
  error: () => undefined,
};

/** No-op file storage for integration tests — avoids real S3 calls. */
const noopFileStorage: FileStorage = {
  deleteObject(): Promise<void> {
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
};

describe.skipIf(!dbUrl)('SweepRetainedSelfiesUseCase (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let selfieRepo: SelfiePrismaRepository;
  let pendingRepo: PendingStorageDeletePrismaRepository;
  let sweepRunRepo: SweepRunPrismaRepository;
  let auditEventRepo: SelfieDeletionEventPrismaRepository;
  let publisher: FakeEventPublisher;
  let clock: FixedClock;
  let useCase: SweepRetainedSelfiesUseCase;

  const NOW = new Date('2026-07-01T00:00:00Z');
  const THIRTY_ONE_DAYS_AGO = new Date(NOW.getTime() - 31 * 24 * 60 * 60 * 1000);

  const trackedUserIds = new Set<string>();
  const trackedSelfieIds = new Set<string>();
  const trackedSweepRunIds = new Set<string>();

  const seedUser = async (): Promise<string> => {
    const id = createId();
    trackedUserIds.add(id);
    await db.user.create({
      data: { id, email: `sweep-int-${id}@tri79.test`, displayName: 'Sweep Integration' },
    });
    return id;
  };

  const seedSelfie = async (
    userId: string,
    opts: {
      status: 'approved' | 'rejected';
      storageKey?: string | null;
      approvedAt?: Date | null;
      rejectedAt?: Date | null;
    },
  ): Promise<string> => {
    const id = createId();
    trackedSelfieIds.add(id);
    const now = new Date();
    await db.selfie.create({
      data: {
        id,
        userId,
        status: opts.status,
        storageKey: opts.storageKey !== undefined ? opts.storageKey : `uploads/${userId}/${id}.jpg`,
        approvedAt: opts.approvedAt !== undefined ? opts.approvedAt : THIRTY_ONE_DAYS_AGO,
        rejectedAt: opts.rejectedAt !== undefined ? opts.rejectedAt : null,
        deletedAt: null,
        createdAt: THIRTY_ONE_DAYS_AGO,
        updatedAt: now,
      },
    });
    return id;
  };

  beforeAll(() => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    selfieRepo = new SelfiePrismaRepository(db);
    pendingRepo = new PendingStorageDeletePrismaRepository(db);
    sweepRunRepo = new SweepRunPrismaRepository(db);
    auditEventRepo = new SelfieDeletionEventPrismaRepository(db);
    publisher = new FakeEventPublisher();
    clock = new FixedClock(NOW);

    const recordSelfieDeletion = new RecordSelfieDeletionUseCase(auditEventRepo);
    useCase = new SweepRetainedSelfiesUseCase(
      unitOfWork,
      selfieRepo,
      pendingRepo,
      sweepRunRepo,
      recordSelfieDeletion,
      publisher,
      noopFileStorage,
      clock,
      noopLogger,
    );
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // Clean up all data seeded by these tests.
    if (trackedSweepRunIds.size > 0) {
      await db.sweepRun.deleteMany({ where: { id: { in: [...trackedSweepRunIds] } } });
    }
    // Clean all sweep_runs written by test executions (kind-scoped to avoid collisions).
    await db.sweepRun.deleteMany({ where: { kind: 'selfie-retention-sweep' } });
    if (trackedSelfieIds.size > 0) {
      await db.selfieDeletionEvent.deleteMany({
        where: { selfieId: { in: [...trackedSelfieIds] } },
      });
      await db.outboxEvent.deleteMany({
        where: { aggregateType: 'Selfie', aggregateId: { in: [...trackedSelfieIds] } },
      });
      await db.selfie.deleteMany({ where: { id: { in: [...trackedSelfieIds] } } });
    }
    for (const userId of trackedUserIds) {
      await db.user.delete({ where: { id: userId } }).catch(() => null);
    }
    await db.$disconnect();
  });

  describe('audit-row atomicity (tx abort leaves no rows)', () => {
    it('selfie row and selfie_deletion_events row both absent after aborted tx', async () => {
      const userId = await seedUser();
      const selfieId = await seedSelfie(userId, { status: 'approved' });
      const selfie = Selfie.rehydrate({
        id: selfieId,
        userId,
        status: 'approved',
        storageKey: `uploads/${userId}/${selfieId}.jpg`,
        approvedAt: THIRTY_ONE_DAYS_AGO,
        rejectedAt: null,
        deletedAt: null,
        createdAt: THIRTY_ONE_DAYS_AGO,
        updatedAt: THIRTY_ONE_DAYS_AGO,
      });

      const recordSelfieDeletion = new RecordSelfieDeletionUseCase(auditEventRepo);

      // Manually run a transaction that marks deleted + records audit, then aborts.
      await expect(
        unitOfWork.run(async (ctx) => {
          selfie.markDeleted(NOW, 'retention-sweep');
          await selfieRepo.save(selfie, ctx);
          await publisher.publish(ctx, ...selfie.pullEvents());
          await recordSelfieDeletion.execute(
            { userId, selfieId, reason: 'retention-sweep', deletedAt: NOW },
            ctx,
          );
          // Force rollback
          throw new Error('deliberate abort');
        }),
      ).rejects.toThrow('deliberate abort');

      // Selfie row should still be 'approved' (not 'deleted')
      const row = await db.selfie.findUnique({ where: { id: selfieId } });
      expect(row?.status).toBe('approved');

      // Audit row should be absent
      const auditRows = await db.selfieDeletionEvent.findMany({ where: { selfieId } });
      expect(auditRows).toHaveLength(0);
    });
  });

  describe('sweep_runs row written per execute', () => {
    it('creates one sweep_runs row queryable by kind=selfie-retention-sweep', async () => {
      await runAsSystem('test.sweep-runs', async () => {
        await useCase.execute();
      });

      const rows = await db.sweepRun.findMany({
        where: { kind: 'selfie-retention-sweep' },
        orderBy: { startedAt: 'desc' },
        take: 1,
      });

      expect(rows).toHaveLength(1);
      expect(rows[0]?.kind).toBe('selfie-retention-sweep');
      expect(rows[0]?.startedAt).toEqual(NOW);
    });
  });

  describe('end-to-end: eligible selfie gets processed and sweep_runs written', () => {
    it('approved selfie marked deleted, audit row present, sweep_runs row written', async () => {
      const userId = await seedUser();
      const selfieId = await seedSelfie(userId, {
        status: 'approved',
        approvedAt: THIRTY_ONE_DAYS_AGO,
      });

      const beforeCount = await db.sweepRun.count({ where: { kind: 'selfie-retention-sweep' } });

      await runAsSystem('test.e2e-sweep', async () => {
        const result = await useCase.execute();
        expect(result.evaluated).toBeGreaterThanOrEqual(1);
        expect(result.deleted).toBeGreaterThanOrEqual(1);
      });

      // Selfie should be deleted
      const selfieRow = await db.selfie.findUnique({ where: { id: selfieId } });
      expect(selfieRow?.status).toBe('deleted');
      expect(selfieRow?.storageKey).toBeNull();

      // Audit row present
      const auditRows = await db.selfieDeletionEvent.findMany({ where: { selfieId } });
      expect(auditRows.length).toBeGreaterThanOrEqual(1);
      expect(auditRows[0]?.reason).toBe('retention-sweep');

      // sweep_runs row added
      const afterCount = await db.sweepRun.count({ where: { kind: 'selfie-retention-sweep' } });
      expect(afterCount).toBe(beforeCount + 1);
    });
  });
});
