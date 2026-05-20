// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { sha256Hex } from '@/core/crypto/sha256-hex.js';
import { buildContainer } from '@/core/di/container.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * Use-case–level integration test for DeleteAccountUseCase (TRI-155).
 *
 * Covers the three new cascade adapters wired in Brief B:
 *   - cascadeReportsOnUserDeletionUseCase
 *   - cascadeReviewsOnUserDeletionUseCase
 *   - cascadeUserBlocksOnUserDeletionUseCase
 *
 * Does NOT repeat the HTTP routing, selfie, check-in, or outbox assertions —
 * those are already covered by the route-level integration test at
 * features/users/presentation/http/routes/delete-account.integration.test.ts.
 *
 * Two test sections:
 *   1. Happy path — seed, delete, assert zero cascade rows, assert unrelated rows survive.
 *   2. Atomicity — mid-tx failure rolls back all cascade work (zero partial deletions).
 *
 * Test isolation: consumer_offsets wiped in beforeAll (CLAUDE.md MIN(committedSeq)
 * dev-DB pollution gotcha). All seeded rows cleaned up in afterAll.
 */
describe.skipIf(!dbUrl)('DeleteAccountUseCase — cascade integration (TRI-155)', () => {
  let db: PrismaClient;

  // Subject (the user being deleted)
  let subjectId: string;

  // Counterparty users
  let counterparty1Id: string;
  let counterparty2Id: string;

  // Event hosted by subject (required for events_hosted cascade — also satisfies review FK)
  let subjectEventId: string;

  // Review rows
  let reviewBySubjectId: string;  // subject is rater
  let reviewAboutSubjectId: string;  // subject is rated

  // Report rows
  let reportBySubjectId: string;       // subject is reporter
  let reportTargetingSubjectReviewId: string;  // counterparty reports one of subject's reviews

  // UserBlock rows
  let userBlockSubjectInitiatorId: string;  // subject blocks counterparty1
  let userBlockSubjectBlockedId: string;    // counterparty2 blocks subject

  // Unrelated rows (must survive after cascade)
  let unrelatedReviewId: string;
  let unrelatedReportId: string;
  let unrelatedUserBlockId: string;

  // An event for the counterparty reviewer (review FK requires eventId)
  let counterpartyEventId: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });

    // TRI-134: wipe consumer_offsets before fixture seeding to prevent
    // MIN(committedSeq) dev-DB pollution from affecting outbox boundary.
    await db.consumerOffset.deleteMany({});

    // ── 1. Seed users ───────────────────────────────────────────────────────
    subjectId = createId();
    counterparty1Id = createId();
    counterparty2Id = createId();

    await db.user.createMany({
      data: [
        {
          id: subjectId,
          email: `tri155-subject-${subjectId}@test.local`,
          displayName: 'TRI-155 Subject',
          emailVerifiedAt: new Date(),
        },
        {
          id: counterparty1Id,
          email: `tri155-cp1-${counterparty1Id}@test.local`,
          displayName: 'TRI-155 Counterparty1',
        },
        {
          id: counterparty2Id,
          email: `tri155-cp2-${counterparty2Id}@test.local`,
          displayName: 'TRI-155 Counterparty2',
        },
      ],
    });

    // ── 2. Seed events (required FK for review rows) ──────────────────────
    subjectEventId = createId();
    counterpartyEventId = createId();

    await db.event.createMany({
      data: [
        {
          id: subjectEventId,
          hostUserId: subjectId,
          title: 'TRI-155 Subject Event',
          venueAddress: '18 Raffles Quay',
          venueCity: 'Singapore',
          venueLatitude: 1.2806,
          venueLongitude: 103.8504,
          venueCategory: 'cafe',
          startsAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // past
          endsAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
          capacity: 5,
          category: 'food',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'active',
        },
        {
          id: counterpartyEventId,
          hostUserId: counterparty1Id,
          title: 'TRI-155 Counterparty Event',
          venueAddress: '18 Raffles Quay',
          venueCity: 'Singapore',
          venueLatitude: 1.2806,
          venueLongitude: 103.8504,
          venueCategory: 'cafe',
          startsAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
          endsAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
          capacity: 5,
          category: 'food',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'active',
        },
      ],
    });

    // ── 3. Seed reviews ────────────────────────────────────────────────────
    // reviewBySubject: subject is rater, counterparty1 is rated
    reviewBySubjectId = createId();
    await db.review.create({
      data: {
        id: reviewBySubjectId,
        eventId: subjectEventId,
        raterUserId: subjectId,
        ratedUserId: counterparty1Id,
        rating: 4,
        comment: 'TRI-155 review by subject',
      },
    });

    // reviewAboutSubject: counterparty1 is rater, subject is rated
    reviewAboutSubjectId = createId();
    await db.review.create({
      data: {
        id: reviewAboutSubjectId,
        eventId: subjectEventId,
        raterUserId: counterparty1Id,
        ratedUserId: subjectId,
        rating: 3,
        comment: 'TRI-155 review about subject',
      },
    });

    // unrelatedReview: counterparty1 rates counterparty2 (must survive)
    unrelatedReviewId = createId();
    await db.review.create({
      data: {
        id: unrelatedReviewId,
        eventId: counterpartyEventId,
        raterUserId: counterparty1Id,
        ratedUserId: counterparty2Id,
        rating: 5,
        comment: 'TRI-155 unrelated review',
      },
    });

    // ── 4. Seed reports ────────────────────────────────────────────────────
    // reportBySubject: subject reports the unrelated review
    reportBySubjectId = createId();
    await db.report.create({
      data: {
        id: reportBySubjectId,
        reporterUserId: subjectId,
        targetType: 'review',
        targetId: unrelatedReviewId,
        reason: 'harassment',
      },
    });

    // reportTargetingSubjectReview: counterparty1 reports one of subject's reviews
    reportTargetingSubjectReviewId = createId();
    await db.report.create({
      data: {
        id: reportTargetingSubjectReviewId,
        reporterUserId: counterparty1Id,
        targetType: 'review',
        targetId: reviewBySubjectId,
        reason: 'harassment',
      },
    });

    // unrelatedReport: counterparty1 reports counterparty2 (must survive)
    unrelatedReportId = createId();
    await db.report.create({
      data: {
        id: unrelatedReportId,
        reporterUserId: counterparty1Id,
        targetType: 'review',
        targetId: unrelatedReviewId,
        reason: 'harassment',
      },
    });

    // ── 5. Seed user_blocks ────────────────────────────────────────────────
    userBlockSubjectInitiatorId = createId();
    await db.userBlock.create({
      data: {
        id: userBlockSubjectInitiatorId,
        initiatorUserId: subjectId,
        blockedUserId: counterparty1Id,
      },
    });

    userBlockSubjectBlockedId = createId();
    await db.userBlock.create({
      data: {
        id: userBlockSubjectBlockedId,
        initiatorUserId: counterparty2Id,
        blockedUserId: subjectId,
      },
    });

    // unrelatedUserBlock: counterparty1 blocks counterparty2 (must survive)
    unrelatedUserBlockId = createId();
    await db.userBlock.create({
      data: {
        id: unrelatedUserBlockId,
        initiatorUserId: counterparty1Id,
        blockedUserId: counterparty2Id,
      },
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;

    // Clean up in reverse dependency order.
    await db.accountDeletionEvent
      .deleteMany({ where: { userIdHash: sha256Hex(subjectId) } })
      .catch(() => null);

    // reports (some may already be deleted by cascade)
    await db.report
      .deleteMany({ where: { id: { in: [reportBySubjectId, reportTargetingSubjectReviewId, unrelatedReportId].filter(Boolean) } } })
      .catch(() => null);

    // reviews (some may already be deleted by cascade)
    await db.review
      .deleteMany({ where: { id: { in: [reviewBySubjectId, reviewAboutSubjectId, unrelatedReviewId].filter(Boolean) } } })
      .catch(() => null);

    // user_blocks (some may already be deleted by cascade)
    await db.userBlock
      .deleteMany({ where: { id: { in: [userBlockSubjectInitiatorId, userBlockSubjectBlockedId, unrelatedUserBlockId].filter(Boolean) } } })
      .catch(() => null);

    // events
    await db.event
      .deleteMany({ where: { id: { in: [subjectEventId, counterpartyEventId].filter(Boolean) } } })
      .catch(() => null);

    // users (subject has deletedAt set after cascade — delete by id)
    await db.user
      .deleteMany({ where: { id: { in: [subjectId, counterparty1Id, counterparty2Id].filter(Boolean) } } })
      .catch(() => null);

    await db.$disconnect();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Happy path
  // ──────────────────────────────────────────────────────────────────────────

  describe('happy path', () => {
    it('executes without throwing', async () => {
      const container = buildContainer();
      await expect(
        container.deleteAccountUseCase.execute({ userId: subjectId }),
      ).resolves.toBeUndefined();
    });

    it('deletes all reviews where subject is rater or rated', async () => {
      const remaining = await db.review.findMany({
        where: {
          OR: [{ raterUserId: subjectId }, { ratedUserId: subjectId }],
        },
      });
      expect(remaining).toHaveLength(0);
    });

    it('deletes reports filed BY subject', async () => {
      const row = await db.report.findUnique({ where: { id: reportBySubjectId } });
      expect(row).toBeNull();
    });

    it('deletes reports targeting reviews authored by or about subject', async () => {
      const row = await db.report.findUnique({ where: { id: reportTargetingSubjectReviewId } });
      expect(row).toBeNull();
    });

    it('deletes user_blocks where subject is initiator or blocked', async () => {
      const initiatorRow = await db.userBlock.findUnique({
        where: { id: userBlockSubjectInitiatorId },
      });
      const blockedRow = await db.userBlock.findUnique({
        where: { id: userBlockSubjectBlockedId },
      });
      expect(initiatorRow).toBeNull();
      expect(blockedRow).toBeNull();
    });

    it('leaves the unrelated review intact', async () => {
      const row = await db.review.findUnique({ where: { id: unrelatedReviewId } });
      expect(row).not.toBeNull();
    });

    it('leaves the unrelated report intact', async () => {
      const row = await db.report.findUnique({ where: { id: unrelatedReportId } });
      expect(row).not.toBeNull();
    });

    it('leaves the unrelated user_block intact', async () => {
      const row = await db.userBlock.findUnique({ where: { id: unrelatedUserBlockId } });
      expect(row).not.toBeNull();
    });

    it('tombstones the user row (deletedAt non-null, email placeholder)', async () => {
      const row = await db.user.findUnique({ where: { id: subjectId } });
      expect(row).not.toBeNull();
      expect(row?.deletedAt).not.toBeNull();
      expect(row?.email).toMatch(/^deleted-.+@deleted\.tribely\.local$/);
    });

    it('writes an account_deletion_events row with outcome=completed and 14 cascadeScope values including the three new scopes', async () => {
      const rows = await db.accountDeletionEvent.findMany({
        where: { userIdHash: sha256Hex(subjectId) },
      });
      expect(rows).toHaveLength(1);
      const row = rows[0];
      expect(row?.outcome).toBe('completed');
      expect(row?.failureReason).toBeNull();

      // Three new scopes (TRI-155) inserted after http_audit_logs_actor_hashed,
      // before the tombstone 'users' scope.
      const scope = row?.cascadeScope as string[];
      expect(scope).toContain('reports_deleted');
      expect(scope).toContain('reviews_deleted');
      expect(scope).toContain('user_blocks_deleted');
      // Full length: 11 original + 3 new = 14
      expect(scope).toHaveLength(14);

      // Verify invocation order: reports → reviews → user_blocks → users
      const reportsIdx = scope.indexOf('reports_deleted');
      const reviewsIdx = scope.indexOf('reviews_deleted');
      const userBlocksIdx = scope.indexOf('user_blocks_deleted');
      const usersIdx = scope.indexOf('users');
      expect(reportsIdx).toBeLessThan(reviewsIdx);
      expect(reviewsIdx).toBeLessThan(userBlocksIdx);
      expect(userBlocksIdx).toBeLessThan(usersIdx);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Atomicity — mid-tx abort rolls back all cascade work
  // ──────────────────────────────────────────────────────────────────────────

  describe('atomicity — mid-tx abort', () => {
    // Seed a fresh subject for the failure-path test so the happy-path subject
    // (already tombstoned) doesn't interfere with this guard check.
    let atomicSubjectId: string;
    let atomicReviewId: string;
    let atomicReportId: string;
    let atomicBlockId: string;
    let atomicEventId: string;

    beforeAll(async () => {
      if (!dbUrl) return;

      atomicSubjectId = createId();
      const atomicCounterpartyId = createId();
      atomicEventId = createId();

      await db.user.createMany({
        data: [
          {
            id: atomicSubjectId,
            email: `tri155-atomic-${atomicSubjectId}@test.local`,
            displayName: 'TRI-155 Atomic Subject',
            emailVerifiedAt: new Date(),
          },
          {
            id: atomicCounterpartyId,
            email: `tri155-atomic-cp-${atomicCounterpartyId}@test.local`,
            displayName: 'TRI-155 Atomic Counterparty',
          },
        ],
      });

      await db.event.create({
        data: {
          id: atomicEventId,
          hostUserId: atomicSubjectId,
          title: 'TRI-155 Atomic Event',
          venueAddress: '18 Raffles Quay',
          venueCity: 'Singapore',
          venueLatitude: 1.2806,
          venueLongitude: 103.8504,
          venueCategory: 'cafe',
          startsAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
          endsAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
          capacity: 5,
          category: 'food',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'active',
        },
      });

      atomicReviewId = createId();
      await db.review.create({
        data: {
          id: atomicReviewId,
          eventId: atomicEventId,
          raterUserId: atomicSubjectId,
          ratedUserId: atomicCounterpartyId,
          rating: 4,
        },
      });

      atomicReportId = createId();
      await db.report.create({
        data: {
          id: atomicReportId,
          reporterUserId: atomicSubjectId,
          targetType: 'review',
          targetId: atomicReviewId,
          reason: 'harassment',
        },
      });

      atomicBlockId = createId();
      await db.userBlock.create({
        data: {
          id: atomicBlockId,
          initiatorUserId: atomicSubjectId,
          blockedUserId: atomicCounterpartyId,
        },
      });
    });

    afterAll(async () => {
      if (!dbUrl) return;

      // Clean up atomic test fixtures (the cascade may or may not have run
      // depending on where the failure occurred — delete all tolerantly).
      await db.accountDeletionEvent
        .deleteMany({ where: { userIdHash: sha256Hex(atomicSubjectId) } })
        .catch(() => null);
      await db.report.deleteMany({ where: { id: atomicReportId } }).catch(() => null);
      await db.review.deleteMany({ where: { id: atomicReviewId } }).catch(() => null);
      await db.userBlock.deleteMany({ where: { id: atomicBlockId } }).catch(() => null);
      await db.event.deleteMany({ where: { id: atomicEventId } }).catch(() => null);
      await db.user.deleteMany({ where: { id: atomicSubjectId } }).catch(() => null);
    });

    it('rolls back all cascade work when the tombstone step fails (no partial deletions)', async () => {
      // Arrange: build a container and replace the userRepository.save method
      // with one that throws mid-transaction, after the cascade adapters
      // (reviews/reports/user_blocks) have already run but before the tx commits.
      // This simulates a failure in the tombstone step (step 9).
      const container = buildContainer();
      const originalSave = container.userRepository.save.bind(container.userRepository);
      let saveCallCount = 0;
      container.userRepository.save = async (user, ctx) => {
        saveCallCount++;
        if (saveCallCount === 1 && user.id === atomicSubjectId) {
          throw new Error('TRI-155 simulated tombstone failure');
        }
        return originalSave(user, ctx);
      };

      // Act: invoke the use case — expect it to throw from the failure path
      // (which opens a clean second tx for the failed_rolled_back audit row)
      await expect(
        container.deleteAccountUseCase.execute({ userId: atomicSubjectId }),
      ).rejects.toThrow('TRI-155 simulated tombstone failure');

      // Assert: cascade rows must NOT be deleted (rollback restores them)
      const reviewRow = await db.review.findUnique({ where: { id: atomicReviewId } });
      const reportRow = await db.report.findUnique({ where: { id: atomicReportId } });
      const blockRow = await db.userBlock.findUnique({ where: { id: atomicBlockId } });

      expect(reviewRow).not.toBeNull();
      expect(reportRow).not.toBeNull();
      expect(blockRow).not.toBeNull();

      // Assert: user is NOT tombstoned
      const userRow = await db.user.findUnique({ where: { id: atomicSubjectId } });
      expect(userRow?.deletedAt).toBeNull();

      // Assert: one failure audit row exists (from the clean second tx)
      const auditRows = await db.accountDeletionEvent.findMany({
        where: { userIdHash: sha256Hex(atomicSubjectId) },
      });
      expect(auditRows).toHaveLength(1);
      expect(auditRows[0]?.outcome).toBe('failed_rolled_back');
    });
  });
});
