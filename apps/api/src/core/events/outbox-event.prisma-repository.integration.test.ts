// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { sha256Hex } from '@/core/crypto/sha256-hex.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';

import { OutboxEventPrismaRepository } from './outbox-event.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * Integration tests for OutboxEventPrismaRepository.pseudonymiseUndispatchedPayloadsForUser.
 *
 * Test matrix (per brief spec):
 *   (a) Un-dispatched event referencing user X in payload.userId → redacted.
 *   (b) Already-dispatched event referencing user X in payload.userId → untouched.
 *   (c) Un-dispatched event NOT referencing X in payload → untouched.
 *
 * We also verify:
 *   - payload.actorUserId key redaction.
 *   - top-level "actorUserId" column redaction.
 *   - Returns combined count of affected rows across all three passes.
 *
 * Consumer offset seeding:
 *   The "dispatched" boundary is defined by MIN(committed_seq) across all
 *   consumer_offsets rows. We insert a synthetic consumer offset row to set
 *   that boundary for each test group that needs it.
 */
describe.skipIf(!dbUrl)('OutboxEventPrismaRepository (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let repo: OutboxEventPrismaRepository;

  /** Track outbox row ids for cleanup. */
  const trackedOutboxIds = new Set<string>();
  /** Track synthetic consumer offset names for cleanup. */
  const trackedConsumerNames = new Set<string>();

  /**
   * Seed an outbox row directly via Prisma — bypasses the publisher so we
   * control `seq` indirectly (auto-assigned by DB) and `actorUserId`.
   * Returns the db row (with the DB-assigned `seq`).
   */
  const seedOutboxRow = async (opts: {
    payload: Record<string, unknown>;
    actorUserId?: string | null;
    type?: string;
  }) => {
    const id = createId();
    trackedOutboxIds.add(id);
    const row = await db.outboxEvent.create({
      data: {
        id,
        type: opts.type ?? 'test.eventType',
        aggregateType: 'TestAggregate',
        aggregateId: createId(),
        // eslint-disable-next-line @typescript-eslint/no-unnecessary-type-assertion -- Prisma's InputJsonValue excludes `unknown`; cast bridges Record<string,unknown> → object
        payload: opts.payload as object,
        actorUserId: opts.actorUserId ?? null,
        requestId: null,
      },
    });
    return row;
  };

  /**
   * Seed a synthetic consumer_offset row that marks all rows up to
   * `committedSeq` as dispatched.
   */
  const seedConsumerOffset = async (committedSeq: bigint): Promise<string> => {
    const consumerName = `test-consumer-${createId()}`;
    trackedConsumerNames.add(consumerName);
    await db.consumerOffset.create({
      data: {
        consumerName,
        topic: 'test.eventType',
        committedSeq,
      },
    });
    return consumerName;
  };

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    repo = new OutboxEventPrismaRepository(db);

    // TRI-134: initial wipe of consumer_offsets — beforeEach repeats this wipe
    // to handle dev-server dispatcher re-insertions between tests (see beforeEach).
    await db.consumerOffset.deleteMany({});
  });

  beforeEach(async () => {
    if (!dbUrl) return;
    if (trackedOutboxIds.size > 0) {
      await db.outboxEvent.deleteMany({ where: { id: { in: [...trackedOutboxIds] } } });
      trackedOutboxIds.clear();
    }
    // Wipe all consumer_offsets (tracked and any re-inserted by the dev-server
    // dispatcher between tests). The dev server's OutboxDispatcher.tickOnce()
    // upserts application consumer rows at committedSeq=0 on each tick
    // (see outbox-dispatcher.ts driveConsumer). Those rows pull MIN("committedSeq")
    // to 0, breaking the dispatched/un-dispatched boundary for tests that seed
    // a consumer_offset at seq N > 0. Wiping unconditionally in beforeEach
    // ensures each test sees a clean table regardless of dispatcher timing.
    await db.consumerOffset.deleteMany({});
    trackedConsumerNames.clear();
  });

  afterAll(async () => {
    if (!dbUrl) return;
    if (trackedOutboxIds.size > 0) {
      await db.outboxEvent
        .deleteMany({ where: { id: { in: [...trackedOutboxIds] } } })
        .catch(() => null);
    }
    if (trackedConsumerNames.size > 0) {
      await db.consumerOffset
        .deleteMany({ where: { consumerName: { in: [...trackedConsumerNames] } } })
        .catch(() => null);
    }
    await db.$disconnect();
  });

  describe('brief test matrix (a/b/c)', () => {
    it('(a) redacts un-dispatched row with payload.userId = userX; (b) leaves dispatched row untouched; (c) leaves un-dispatched row for different user untouched', async () => {
      const userX = createId();
      const userY = createId();
      const pseudonymX = sha256Hex(userX);

      // Seed three rows in sequence — seq is auto-assigned BIGSERIAL.
      const rowA = await seedOutboxRow({ payload: { userId: userX, other: 'data' } }); // (a) un-dispatched, references X
      const rowB = await seedOutboxRow({ payload: { userId: userX, other: 'data' } }); // (b) will be marked dispatched
      const rowC = await seedOutboxRow({ payload: { userId: userY, other: 'data' } }); // (c) un-dispatched, references Y

      // Mark row B as dispatched: set MIN(committed_seq) = rowB.seq, so
      // `seq > rowB.seq` is the un-dispatched boundary → only rowA is below
      // that boundary. Wait — we want rowA to be un-dispatched and rowB to be
      // dispatched. So we set committed_seq = rowB.seq (rowB.seq is committed,
      // rowC.seq > rowB.seq is un-dispatched).
      //
      // But rowA.seq < rowB.seq < rowC.seq typically. With MIN = rowB.seq:
      //   - rowA.seq <= rowB.seq → rowA.seq > rowB.seq is FALSE → dispatched
      //   - rowC.seq > rowB.seq → un-dispatched
      //
      // That doesn't match the test intent. We need committed_seq < rowA.seq
      // for rowA to be un-dispatched, or we need rowB to be individually marked
      // without a global offset affecting rowA.
      //
      // The correct approach: set committed_seq = rowB.seq. Then:
      //   - seq > MIN(committed_seq) = seq > rowB.seq
      //   - rowA.seq < rowB.seq → NOT un-dispatched (already past rowA)
      //   This still doesn't work as the "dispatched" marker for rowB only.
      //
      // The real semantics: committed_seq = N means "all rows with seq <= N are
      // dispatched". To make rowB dispatched but rowA and rowC not, we need to
      // ensure seq(rowA) > committed_seq AND seq(rowB) <= committed_seq.
      //
      // Since rows are inserted in order, seq(rowA) < seq(rowB) < seq(rowC).
      // There is no committed_seq value such that rowA is un-dispatched AND
      // rowB is dispatched AND rowC is un-dispatched, given the ordering.
      //
      // Revised test: seed in a different order to get the right boundary.
      // Dispatched row (B) is seeded FIRST (lower seq), undispatched rows
      // (A and C) are seeded AFTER (higher seq). Set committed_seq = rowB.seq.

      // Delete the rows we just inserted — we'll re-seed in the right order.
      await db.outboxEvent.deleteMany({
        where: { id: { in: [rowA.id, rowB.id, rowC.id] } },
      });
      trackedOutboxIds.delete(rowA.id);
      trackedOutboxIds.delete(rowB.id);
      trackedOutboxIds.delete(rowC.id);

      // Re-seed: dispatched row first, then un-dispatched rows.
      const dispatched = await seedOutboxRow({ payload: { userId: userX, other: 'data' } }); // (b) dispatched
      const undispatchedX = await seedOutboxRow({ payload: { userId: userX, other: 'data' } }); // (a) un-dispatched, references X
      const undispatchedY = await seedOutboxRow({ payload: { userId: userY, other: 'data' } }); // (c) un-dispatched, references Y

      // Commit consumer offset at dispatched.seq → dispatched row is processed.
      await seedConsumerOffset(dispatched.seq);

      // Purge any consumer_offset rows the external dev-server dispatcher may
      // have inserted since beforeEach — at committedSeq=0 (initial upsert) OR
      // at any non-zero seq the long-running dispatcher has already advanced
      // to. Any such row pulls MIN("committedSeq") below dispatched.seq,
      // defeating the boundary this test asserts. We preserve only the
      // test-seeded names tracked in `trackedConsumerNames` for this test.
      await db.consumerOffset.deleteMany({
        where: { consumerName: { notIn: [...trackedConsumerNames] } },
      });

      const count = await unitOfWork.run((ctx) =>
        repo.pseudonymiseUndispatchedPayloadsForUser(userX, pseudonymX, ctx),
      );

      // At least 1 pass updated (payload.userId for undispatchedX).
      expect(count).toBeGreaterThanOrEqual(1);

      // (a) Un-dispatched row referencing X: payload.userId → hash.
      const redactedRow = await db.outboxEvent.findUnique({ where: { id: undispatchedX.id } });
      const redactedPayload = redactedRow?.payload as Record<string, unknown>;
      expect(redactedPayload['userId']).toBe(pseudonymX);
      expect(redactedPayload['other']).toBe('data'); // other fields preserved

      // (b) Dispatched row: payload untouched.
      const dispatchedRow = await db.outboxEvent.findUnique({ where: { id: dispatched.id } });
      const dispatchedPayload = dispatchedRow?.payload as Record<string, unknown>;
      expect(dispatchedPayload['userId']).toBe(userX); // original value retained

      // (c) Un-dispatched row for Y: payload untouched.
      const yRow = await db.outboxEvent.findUnique({ where: { id: undispatchedY.id } });
      const yPayload = yRow?.payload as Record<string, unknown>;
      expect(yPayload['userId']).toBe(userY); // Y's id unchanged
    });
  });

  describe('payload.actorUserId key redaction', () => {
    it('redacts payload.actorUserId for un-dispatched rows referencing the user', async () => {
      const userId = createId();
      const pseudonym = sha256Hex(userId);

      const row = await seedOutboxRow({
        payload: { actorUserId: userId, eventId: 'some-event' },
      });
      // No consumer offset → MIN returns NULL → COALESCE to -1 → all rows un-dispatched.

      await unitOfWork.run((ctx) =>
        repo.pseudonymiseUndispatchedPayloadsForUser(userId, pseudonym, ctx),
      );

      const updated = await db.outboxEvent.findUnique({ where: { id: row.id } });
      const payload = updated?.payload as Record<string, unknown>;
      expect(payload['actorUserId']).toBe(pseudonym);
      expect(payload['eventId']).toBe('some-event'); // other fields preserved
    });
  });

  describe('"actorUserId" column redaction', () => {
    it('redacts the top-level actorUserId column for un-dispatched rows', async () => {
      const userId = createId();
      const pseudonym = sha256Hex(userId);

      const row = await seedOutboxRow({
        payload: { someField: 'value' },
        actorUserId: userId,
      });

      const count = await unitOfWork.run((ctx) =>
        repo.pseudonymiseUndispatchedPayloadsForUser(userId, pseudonym, ctx),
      );

      // Pass 3 (column update) contributes at least 1 to the count.
      expect(count).toBeGreaterThanOrEqual(1);

      const updated = await db.outboxEvent.findUnique({ where: { id: row.id } });
      expect(updated?.actorUserId).toBe(pseudonym);
    });

    it('does NOT redact actorUserId column for dispatched rows', async () => {
      const userId = createId();
      const pseudonym = sha256Hex(userId);

      const dispatched = await seedOutboxRow({
        payload: { someField: 'value' },
        actorUserId: userId,
      });
      // Mark as dispatched via consumer offset at dispatched.seq.
      await seedConsumerOffset(dispatched.seq);

      // Purge any consumer_offset rows the external dev-server dispatcher may
      // have inserted since beforeEach — at committedSeq=0 (initial upsert) OR
      // at any non-zero seq the long-running dispatcher has already advanced
      // to. Any such row pulls MIN("committedSeq") below dispatched.seq,
      // defeating the dispatched-boundary assertion. We preserve only the
      // test-seeded names tracked in `trackedConsumerNames` for this test.
      await db.consumerOffset.deleteMany({
        where: { consumerName: { notIn: [...trackedConsumerNames] } },
      });

      await unitOfWork.run((ctx) =>
        repo.pseudonymiseUndispatchedPayloadsForUser(userId, pseudonym, ctx),
      );

      const row = await db.outboxEvent.findUnique({ where: { id: dispatched.id } });
      expect(row?.actorUserId).toBe(userId); // untouched
    });
  });

  describe('edge cases', () => {
    it('returns 0 when no rows match the userId', async () => {
      const unknownUser = createId();
      const count = await unitOfWork.run((ctx) =>
        repo.pseudonymiseUndispatchedPayloadsForUser(unknownUser, sha256Hex(unknownUser), ctx),
      );
      expect(count).toBe(0);
    });

    it('with no consumer_offsets rows, treats all outbox rows as un-dispatched', async () => {
      const userId = createId();
      const pseudonym = sha256Hex(userId);

      const row = await seedOutboxRow({ payload: { userId } });
      // No consumer offset seeded → MIN returns NULL → all rows un-dispatched.

      await unitOfWork.run((ctx) =>
        repo.pseudonymiseUndispatchedPayloadsForUser(userId, pseudonym, ctx),
      );

      const updated = await db.outboxEvent.findUnique({ where: { id: row.id } });
      const payload = updated?.payload as Record<string, unknown>;
      expect(payload['userId']).toBe(pseudonym);
    });

    it('preserves other payload fields when redacting', async () => {
      const userId = createId();
      const pseudonym = sha256Hex(userId);

      const row = await seedOutboxRow({
        payload: {
          userId,
          eventId: 'evt-123',
          category: 'food',
          nested: { keep: true },
        },
      });

      await unitOfWork.run((ctx) =>
        repo.pseudonymiseUndispatchedPayloadsForUser(userId, pseudonym, ctx),
      );

      const updated = await db.outboxEvent.findUnique({ where: { id: row.id } });
      const payload = updated?.payload as Record<string, unknown>;
      expect(payload['userId']).toBe(pseudonym);
      expect(payload['eventId']).toBe('evt-123');
      expect(payload['category']).toBe('food');
      expect(payload['nested']).toEqual({ keep: true });
    });
  });
});
