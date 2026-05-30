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
 * Use-case–level integration test for DeleteAccountUseCase (TRI-155 / TRI-135).
 *
 * Covers the three new cascade adapters wired in Brief B:
 *   - cascadeReportsOnUserDeletionUseCase
 *   - cascadeReviewsOnUserDeletionUseCase
 *   - cascadeUserBlocksOnUserDeletionUseCase
 *
 * TRI-135 Brief 3 extension: asserts real-FK coverage on the check-in cascade
 * path (pending + ok deletion, flagged pseudonymisation, per-row audit trail in
 * post_event_check_in_events, control-row survival).
 *
 * Does NOT repeat the HTTP routing, selfie, or outbox assertions —
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
  let reviewBySubjectId: string; // subject is rater
  let reviewAboutSubjectId: string; // subject is rated

  // Report rows
  let reportBySubjectId: string; // subject is reporter
  let reportTargetingSubjectReviewId: string; // counterparty reports one of subject's reviews

  // UserBlock rows
  let userBlockSubjectInitiatorId: string; // subject blocks counterparty1
  let userBlockSubjectBlockedId: string; // counterparty2 blocks subject

  // SupportTicket row owned by subject (TRI-217)
  let subjectSupportTicketId: string;

  // Unrelated rows (must survive after cascade)
  let unrelatedReviewId: string;
  let unrelatedReportId: string;
  let unrelatedUserBlockId: string;

  // An event for the counterparty reviewer (review FK requires eventId)
  let counterpartyEventId: string;

  // ── TRI-135 Brief 3: post_event_check_ins cascade coverage ────────────────
  // Each check-in needs a distinct (userId, eventId) pair due to @@unique([userId, eventId]).
  // Six fresh events are created — one per check-in row — all hosted by counterparty1Id.

  // Events that serve as FK anchors for the check-in rows
  let checkInEvent1Id: string; // flagged-attendee: subjectId attends, counterparty1Id hosts
  let checkInEvent2Id: string; // pending-1: subjectId attends, counterparty1Id hosts
  let checkInEvent3Id: string; // pending-2: subjectId attends, counterparty1Id hosts
  let checkInEvent4Id: string; // ok-1: subjectId attends, counterparty1Id hosts
  let checkInEvent5Id: string; // ok-2: subjectId attends, counterparty1Id hosts
  let checkInEvent6Id: string; // control pending: counterparty2Id attends (must survive)

  // Check-in row IDs (used in assertions and teardown)
  let checkInFlaggedAttendeeId: string; // flagged; subjectId is attendee — must survive (pseudonymised)
  let checkInFlaggedHostId: string; // flagged; subjectId is host, counterparty1Id is attendee — must survive (pseudonymised)
  let checkInPending1Id: string; // pending; subjectId authored — must be deleted
  let checkInPending2Id: string; // pending; subjectId authored — must be deleted
  let checkInOk1Id: string; // ok; subjectId authored — must be deleted
  let checkInOk2Id: string; // ok; subjectId authored — must be deleted
  let checkInControlId: string; // pending; counterparty2Id authored — must survive

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

    // ── 6. Seed support ticket owned by subject (TRI-217) ─────────────────
    subjectSupportTicketId = createId();
    await db.supportTicket.create({
      data: {
        id: subjectSupportTicketId,
        userId: subjectId,
        userEmailSnapshot: `tri217-subject-${subjectId}@test.local`,
        category: 'other',
        message: 'please reach me at foo@bar.com',
        status: 'open',
      },
    });

    // ── 7. Seed post_event_check_in events and rows (TRI-135 Brief 3) ─────
    // Six new events — one per check-in row — all hosted by counterparty1Id
    // so the @@unique([userId, eventId]) constraint is never violated.
    // The flagged-host check-in reuses subjectEventId (subjectId is host there).
    checkInEvent1Id = createId();
    checkInEvent2Id = createId();
    checkInEvent3Id = createId();
    checkInEvent4Id = createId();
    checkInEvent5Id = createId();
    checkInEvent6Id = createId();

    const checkInEventBase = {
      venueAddress: '18 Raffles Quay',
      venueCity: 'Singapore',
      venueLatitude: 1.2806,
      venueLongitude: 103.8504,
      venueCategory: 'other',
      startsAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
      endsAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
      capacity: 5,
      category: 'food',
      costSplit: 'own',
      approvalMode: 'manual',
      status: 'active',
    };

    await db.event.createMany({
      data: [
        {
          id: checkInEvent1Id,
          hostUserId: counterparty1Id,
          title: 'TRI-135 CheckIn Event 1',
          ...checkInEventBase,
        },
        {
          id: checkInEvent2Id,
          hostUserId: counterparty1Id,
          title: 'TRI-135 CheckIn Event 2',
          ...checkInEventBase,
        },
        {
          id: checkInEvent3Id,
          hostUserId: counterparty1Id,
          title: 'TRI-135 CheckIn Event 3',
          ...checkInEventBase,
        },
        {
          id: checkInEvent4Id,
          hostUserId: counterparty1Id,
          title: 'TRI-135 CheckIn Event 4',
          ...checkInEventBase,
        },
        {
          id: checkInEvent5Id,
          hostUserId: counterparty1Id,
          title: 'TRI-135 CheckIn Event 5',
          ...checkInEventBase,
        },
        {
          id: checkInEvent6Id,
          hostUserId: counterparty1Id,
          title: 'TRI-135 CheckIn Event 6',
          ...checkInEventBase,
        },
      ],
    });

    // Seed check-in rows directly via raw Prisma (no FK constraints on userId/hostUserId
    // after the drop_post_event_check_ins_user_fk migration; eventId FK is still present).
    checkInFlaggedAttendeeId = createId();
    checkInFlaggedHostId = createId();
    checkInPending1Id = createId();
    checkInPending2Id = createId();
    checkInOk1Id = createId();
    checkInOk2Id = createId();
    checkInControlId = createId();

    await db.postEventCheckIn.createMany({
      data: [
        // flagged: subjectId is attendee → must be pseudonymised (userId rewritten), row survives
        {
          id: checkInFlaggedAttendeeId,
          userId: subjectId,
          eventId: checkInEvent1Id,
          hostUserId: counterparty1Id,
          status: 'flagged',
        },
        // flagged: subjectId is host → must be pseudonymised (hostUserId rewritten), row survives
        // Uses subjectEventId so subjectId is the actual host; counterparty1Id is attendee.
        {
          id: checkInFlaggedHostId,
          userId: counterparty1Id,
          eventId: subjectEventId,
          hostUserId: subjectId,
          status: 'flagged',
        },
        // pending×2: subjectId is attendee → must be hard-deleted by cascade
        {
          id: checkInPending1Id,
          userId: subjectId,
          eventId: checkInEvent2Id,
          hostUserId: counterparty1Id,
          status: 'pending',
        },
        {
          id: checkInPending2Id,
          userId: subjectId,
          eventId: checkInEvent3Id,
          hostUserId: counterparty1Id,
          status: 'pending',
        },
        // ok×2: subjectId is attendee → must be hard-deleted by cascade
        {
          id: checkInOk1Id,
          userId: subjectId,
          eventId: checkInEvent4Id,
          hostUserId: counterparty1Id,
          status: 'ok',
        },
        {
          id: checkInOk2Id,
          userId: subjectId,
          eventId: checkInEvent5Id,
          hostUserId: counterparty1Id,
          status: 'ok',
        },
        // control: counterparty2Id is attendee (no subject involvement) → must survive untouched
        {
          id: checkInControlId,
          userId: counterparty2Id,
          eventId: checkInEvent6Id,
          hostUserId: counterparty1Id,
          status: 'pending',
        },
      ],
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;

    // Clean up in reverse dependency order.
    await db.accountDeletionEvent
      .deleteMany({ where: { userIdHash: sha256Hex(subjectId) } })
      .catch(() => null);

    // support tickets (pseudonymised by cascade — userId is NULL, delete by id)
    await db.supportTicket.deleteMany({ where: { id: subjectSupportTicketId } }).catch(() => null);

    // reports (some may already be deleted by cascade)
    await db.report
      .deleteMany({
        where: {
          id: {
            in: [reportBySubjectId, reportTargetingSubjectReviewId, unrelatedReportId].filter(
              Boolean,
            ),
          },
        },
      })
      .catch(() => null);

    // reviews (some may already be deleted by cascade)
    await db.review
      .deleteMany({
        where: {
          id: { in: [reviewBySubjectId, reviewAboutSubjectId, unrelatedReviewId].filter(Boolean) },
        },
      })
      .catch(() => null);

    // user_blocks (some may already be deleted by cascade)
    await db.userBlock
      .deleteMany({
        where: {
          id: {
            in: [
              userBlockSubjectInitiatorId,
              userBlockSubjectBlockedId,
              unrelatedUserBlockId,
            ].filter(Boolean),
          },
        },
      })
      .catch(() => null);

    // post_event_check_in_events audit rows (no FK — delete by userId or checkInId;
    // the cascade may have already written audit rows for subjectId)
    await db.postEventCheckInEvent
      .deleteMany({
        where: {
          checkInId: {
            in: [
              checkInFlaggedAttendeeId,
              checkInFlaggedHostId,
              checkInPending1Id,
              checkInPending2Id,
              checkInOk1Id,
              checkInOk2Id,
              checkInControlId,
              // Also covers aggregate pseudonymised rows whose checkInId === subjectId
              subjectId,
            ].filter(Boolean),
          },
        },
      })
      .catch(() => null);

    // post_event_check_in rows (some already deleted by cascade; tolerant delete by id)
    await db.postEventCheckIn
      .deleteMany({
        where: {
          id: {
            in: [
              checkInFlaggedAttendeeId,
              checkInFlaggedHostId,
              checkInPending1Id,
              checkInPending2Id,
              checkInOk1Id,
              checkInOk2Id,
              checkInControlId,
            ].filter(Boolean),
          },
        },
      })
      .catch(() => null);

    // events (subject event + counterparty event + 6 new check-in events)
    await db.event
      .deleteMany({
        where: {
          id: {
            in: [
              subjectEventId,
              counterpartyEventId,
              checkInEvent1Id,
              checkInEvent2Id,
              checkInEvent3Id,
              checkInEvent4Id,
              checkInEvent5Id,
              checkInEvent6Id,
            ].filter(Boolean),
          },
        },
      })
      .catch(() => null);

    // users (subject has deletedAt set after cascade — delete by id)
    await db.user
      .deleteMany({
        where: { id: { in: [subjectId, counterparty1Id, counterparty2Id].filter(Boolean) } },
      })
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

    it('pseudonymises the support ticket (row retained, PII fields nulled/tombstoned)', async () => {
      const row = await db.supportTicket.findUnique({ where: { id: subjectSupportTicketId } });
      // Row must still exist (retained for audit continuity)
      expect(row).not.toBeNull();
      // userId and userEmailSnapshot must be nulled
      expect(row?.userId).toBeNull();
      expect(row?.userEmailSnapshot).toBeNull();
      // message must be tombstoned with the sentinel string
      expect(row?.message).toBe('[deleted]');
    });

    // ── TRI-135 Brief 3: post_event_check_ins cascade assertions ──────────

    it('hard-deletes pending and ok check-in rows where subject is userId', async () => {
      // No post_event_check_ins row with userId === subjectId and status in (pending, ok)
      // must remain after cascade.
      const surviving = await db.postEventCheckIn.findMany({
        where: {
          userId: subjectId,
          status: { in: ['pending', 'ok'] },
        },
      });
      expect(surviving).toHaveLength(0);
    });

    it('pseudonymises the flagged attendee check-in (row survives, userId rewritten)', async () => {
      const row = await db.postEventCheckIn.findUnique({
        where: { id: checkInFlaggedAttendeeId },
      });
      // Row must still exist (flagged rows are retained for evidentiary value)
      expect(row).not.toBeNull();
      // userId must have been rewritten to a pseudonym (not the original subjectId)
      expect(row?.userId).not.toBe(subjectId);
    });

    it('pseudonymises the flagged host check-in (row survives, hostUserId rewritten)', async () => {
      const row = await db.postEventCheckIn.findUnique({
        where: { id: checkInFlaggedHostId },
      });
      // Row must still exist
      expect(row).not.toBeNull();
      // hostUserId must have been rewritten to a pseudonym (not the original subjectId)
      expect(row?.hostUserId).not.toBe(subjectId);
    });

    it('leaves the control check-in (authored by counterparty2) intact and untouched', async () => {
      const row = await db.postEventCheckIn.findUnique({ where: { id: checkInControlId } });
      expect(row).not.toBeNull();
      expect(row?.userId).toBe(counterparty2Id);
      expect(row?.status).toBe('pending');
    });

    it('writes 4 deleted_by_retention audit rows in post_event_check_in_events (2 pending + 2 ok)', async () => {
      // Each hard-deleted pending/ok check-in row emits one per-row audit entry
      // with reason='deleted_by_retention' carrying the original checkInId.
      const deletedCheckInIds = new Set([
        checkInPending1Id,
        checkInPending2Id,
        checkInOk1Id,
        checkInOk2Id,
      ]);

      const auditRows = await db.postEventCheckInEvent.findMany({
        where: {
          checkInId: { in: [...deletedCheckInIds] },
          reason: 'deleted_by_retention',
        },
      });

      expect(auditRows).toHaveLength(4);

      // Every deleted check-in ID must appear exactly once in the audit trail.
      const auditedCheckInIds = new Set(auditRows.map((r) => r.checkInId));
      for (const id of deletedCheckInIds) {
        expect(auditedCheckInIds).toContain(id);
      }
    });

    it('writes 2 pseudonymised audit rows in post_event_check_in_events (one per flagged batch)', async () => {
      // PseudonymiseCheckInsForUserUseCase emits one aggregate pseudonymised row
      // per pseudonymiseForUser batch (attendee batch + host batch) when count > 0.
      // Both batches ran (one flagged attendee row + one flagged host row), so
      // exactly 2 pseudonymised rows are expected — both with checkInId === subjectId
      // (the synthetic aggregate identifier used by the aggregate-audit pattern).
      const pseudonymisedRows = await db.postEventCheckInEvent.findMany({
        where: {
          checkInId: subjectId,
          reason: 'pseudonymised',
        },
      });
      expect(pseudonymisedRows).toHaveLength(2);
    });

    it('tombstones the user row (deletedAt non-null, email placeholder)', async () => {
      const row = await db.user.findUnique({ where: { id: subjectId } });
      expect(row).not.toBeNull();
      expect(row?.deletedAt).not.toBeNull();
      expect(row?.email).toMatch(/^deleted-.+@deleted\.tribely\.local$/);
    });

    it('writes an account_deletion_events row with outcome=completed and 15 cascadeScope values including the new support_tickets scope', async () => {
      const rows = await db.accountDeletionEvent.findMany({
        where: { userIdHash: sha256Hex(subjectId) },
      });
      expect(rows).toHaveLength(1);
      const row = rows[0];
      expect(row?.outcome).toBe('completed');
      expect(row?.failureReason).toBeNull();

      // Three scopes from TRI-155 + one new scope from TRI-217.
      const scope = row?.cascadeScope as string[];
      expect(scope).toContain('check_ins'); // TRI-135: check-in cascade step present
      expect(scope).toContain('reports_deleted');
      expect(scope).toContain('reviews_deleted');
      expect(scope).toContain('user_blocks_deleted');
      expect(scope).toContain('support_tickets');
      // Full length: 11 original + 3 (TRI-155) + 1 (TRI-217) = 15
      expect(scope).toHaveLength(15);

      // Verify invocation order: reports → reviews → user_blocks → support_tickets → users
      const reportsIdx = scope.indexOf('reports_deleted');
      const reviewsIdx = scope.indexOf('reviews_deleted');
      const userBlocksIdx = scope.indexOf('user_blocks_deleted');
      const supportTicketsIdx = scope.indexOf('support_tickets');
      const usersIdx = scope.indexOf('users');
      expect(reportsIdx).toBeLessThan(reviewsIdx);
      expect(reviewsIdx).toBeLessThan(userBlocksIdx);
      expect(userBlocksIdx).toBeLessThan(supportTicketsIdx);
      expect(supportTicketsIdx).toBeLessThan(usersIdx);
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
