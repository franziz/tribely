// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import type { PendingStorageDeleteEntry } from '../../domain/repositories/pending-storage-delete.repository.js';
import { PendingStorageDeletePrismaRepository } from './pending-storage-delete.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * Integration tests for PendingStorageDeletePrismaRepository against the real
 * Postgres DB. Skipped when DATABASE_URL is unset.
 *
 * The `selfie_pending_storage_deletes` table has NO FK to `selfies` (intentional
 * decoupling — see schema comment), so we can insert entries without a backing
 * selfie row. This makes setup simpler.
 */
describe.skipIf(!dbUrl)('PendingStorageDeletePrismaRepository (integration)', () => {
  let db: PrismaClient;
  let repo: PendingStorageDeletePrismaRepository;

  const trackedIds = new Set<string>();

  const makeEntry = (
    overrides: Partial<PendingStorageDeleteEntry> = {},
  ): PendingStorageDeleteEntry => {
    const id = createId();
    trackedIds.add(id);
    return {
      id,
      selfieId: overrides.selfieId ?? createId(),
      storageKey: overrides.storageKey ?? `uploads/test/${id}.jpg`,
      attempts: overrides.attempts ?? 0,
      enqueuedAt: overrides.enqueuedAt ?? new Date(),
      lastAttemptAt: overrides.lastAttemptAt ?? null,
      lastError: overrides.lastError ?? null,
    };
  };

  beforeAll(() => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    repo = new PendingStorageDeletePrismaRepository(db);
  });

  afterAll(async () => {
    if (!dbUrl) return;
    if (trackedIds.size > 0) {
      await db.selfiePendingStorageDelete.deleteMany({ where: { id: { in: [...trackedIds] } } });
    }
    await db.$disconnect();
  });

  describe('enqueue', () => {
    it('persists a new entry and findPending returns it ordered by enqueuedAt ASC', async () => {
      const entry = makeEntry();

      await repo.enqueue(entry);

      const pending = await repo.findPending();
      const found = pending.find((e) => e.id === entry.id);
      expect(found).not.toBeUndefined();
      if (!found) return;
      expect(found.selfieId).toBe(entry.selfieId);
      expect(found.storageKey).toBe(entry.storageKey);
      expect(found.attempts).toBe(0);
      expect(found.lastAttemptAt).toBeNull();
      expect(found.lastError).toBeNull();
    });

    it('findPending returns entries ordered oldest first (enqueuedAt ASC)', async () => {
      const earlier = makeEntry({ enqueuedAt: new Date('2026-01-01T00:00:00Z') });
      const later = makeEntry({ enqueuedAt: new Date('2026-06-01T00:00:00Z') });

      // Enqueue in reverse order to confirm ordering is by enqueuedAt, not insertion order
      await repo.enqueue(later);
      await repo.enqueue(earlier);

      const pending = await repo.findPending();
      const relevantIds = [earlier.id, later.id];
      const relevant = pending.filter((e) => relevantIds.includes(e.id));

      expect(relevant).toHaveLength(2);
      if (relevant.length < 2) return;
      expect(relevant[0]?.id).toBe(earlier.id);
      expect(relevant[1]?.id).toBe(later.id);
    });
  });

  describe('incrementAttempts', () => {
    it('increments the attempts counter, sets lastAttemptAt, and records lastError', async () => {
      const entry = makeEntry();
      await repo.enqueue(entry);

      const beforeIncrement = await repo.findPending();
      const before = beforeIncrement.find((e) => e.id === entry.id);
      expect(before?.attempts).toBe(0);

      await repo.incrementAttempts(entry.selfieId, 'NoSuchKey: The specified key does not exist');

      const afterIncrement = await repo.findPending();
      const after = afterIncrement.find((e) => e.id === entry.id);
      expect(after?.attempts).toBe(1);
      expect(after?.lastAttemptAt).not.toBeNull();
      expect(after?.lastError).toBe('NoSuchKey: The specified key does not exist');
    });

    it('increments attempts again on subsequent calls', async () => {
      const entry = makeEntry();
      await repo.enqueue(entry);

      await repo.incrementAttempts(entry.selfieId, 'first error');
      await repo.incrementAttempts(entry.selfieId, 'second error');

      const pending = await repo.findPending();
      const found = pending.find((e) => e.id === entry.id);
      expect(found?.attempts).toBe(2);
      expect(found?.lastError).toBe('second error');
    });

    it('sets lastError to null when error is omitted', async () => {
      const entry = makeEntry();
      await repo.enqueue(entry);
      await repo.incrementAttempts(entry.selfieId, 'some error');
      // Call again without error string
      await repo.incrementAttempts(entry.selfieId);

      const pending = await repo.findPending();
      const found = pending.find((e) => e.id === entry.id);
      expect(found?.lastError).toBeNull();
    });
  });

  describe('remove', () => {
    it('removes the entry so findPending no longer returns it', async () => {
      const entry = makeEntry();
      await repo.enqueue(entry);

      await repo.remove(entry.selfieId);

      const pending = await repo.findPending();
      const found = pending.find((e) => e.id === entry.id);
      expect(found).toBeUndefined();
      // Remove from tracked set since we already deleted it
      trackedIds.delete(entry.id);
    });

    it('is idempotent: removing a non-existent selfieId does not throw', async () => {
      await expect(repo.remove(createId())).resolves.toBeUndefined();
    });
  });
});
