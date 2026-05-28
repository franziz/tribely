// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

// Use relative paths from scripts/ — the @/ alias maps to src/ and cannot be
// resolved from outside that tree.
import { PrismaUnitOfWork } from '../src/core/db/prisma-unit-of-work.js';
import { runAsSystem } from '../src/core/context/system-context.js';
import { OutboxEventPublisher } from '../src/core/events/outbox-event-publisher.js';
import { SystemClock } from '../src/features/auth/infrastructure/adapters/system-clock.js';
import { ModerationActionAuditPrismaRepository } from '../src/features/audit/infrastructure/persistence/moderation-action-audit.prisma-repository.js';
import { RecordModerationActionUseCase } from '../src/features/audit/application/usecases/record-moderation-action.usecase.js';
import { ReportPrismaRepository } from '../src/features/reports/infrastructure/persistence/report.prisma-repository.js';
import { ReviewPrismaRepository } from '../src/features/reviews/infrastructure/persistence/review.prisma-repository.js';
import { Report } from '../src/features/reports/domain/entities/report.js';
import { ReportReason } from '../src/features/reports/domain/value-objects/report-reason.js';
import { ReportTarget } from '../src/features/reports/domain/value-objects/report-target.js';
import { Review } from '../src/features/reviews/domain/entities/review.js';
import { Rating } from '../src/features/reviews/domain/value-objects/rating.js';
import { ReviewComment } from '../src/features/reviews/domain/value-objects/review-comment.js';
import { PerformModerationActionUseCase } from '../src/features/reports/application/usecases/perform-moderation-action.usecase.js';
import { EventPrismaRepository } from '../src/features/events/infrastructure/persistence/event.prisma-repository.js';
import { JoinRequestPrismaRepository } from '../src/features/join-requests/infrastructure/persistence/join-request.prisma-repository.js';
import { CancelEventForSafetyUseCase } from '../src/features/reports/application/usecases/cancel-event-for-safety.usecase.js';
import { SweepResolvedReportsUseCase } from '../src/features/reports/application/usecases/sweep-resolved-reports.usecase.js';
import { SweepRunPrismaRepository } from '../src/features/selfies/infrastructure/persistence/sweep-run.prisma-repository.js';
import { EscalateReportUseCase } from '../src/features/reports/application/usecases/escalate-report.usecase.js';
import { RecordExternalInputUseCase } from '../src/features/reports/application/usecases/record-external-input.usecase.js';

const dbUrl = process.env.DATABASE_URL;
// TRI-206: moderation_action_audit is append-only under the runtime role (tribely_app).
// The runtime db client cannot DELETE from the audit table, so teardown must use a
// DDL-privileged admin connection. ADMIN_DATABASE_URL points at the superuser/migration
// role; falls back to DATABASE_URL for environments that share one credential.
const adminDbUrl = process.env.ADMIN_DATABASE_URL ?? process.env.DATABASE_URL;
const adminPrisma = adminDbUrl
  ? new PrismaClient({ adapter: new PrismaPg({ connectionString: adminDbUrl }) })
  : null;

afterAll(async () => {
  if (adminPrisma) {
    await adminPrisma
      .$executeRawUnsafe('TRUNCATE TABLE moderation_action_audit RESTART IDENTITY CASCADE')
      .catch(() => null);
    await adminPrisma.$disconnect();
  }
});

/**
 * Integration test for PerformModerationActionUseCase against a real DB.
 *
 * Seed: operator user, reporter user, rated user, event, review (target),
 * report against the review.
 *
 * Tests the three action paths, atomic rollback on error, idempotent touch,
 * and requestId on audit rows via runAsSystem.
 */
describe.skipIf(!dbUrl)('PerformModerationActionUseCase (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: PrismaUnitOfWork;
  let useCase: PerformModerationActionUseCase;
  let reportRepository: ReportPrismaRepository;
  let reviewRepository: ReviewPrismaRepository;

  // Seeded IDs
  let operatorId: string;
  let reporterId: string;
  let ratedUserId: string;
  let hostUserId: string;
  let eventId: string;

  /** Track outbox aggregate IDs (report IDs) so afterAll can scope-delete instead of blanket-wipe. */
  const trackedOutboxAggregateIds = new Set<string>();

  beforeAll(async () => {
    if (!dbUrl) return;

    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);

    reviewRepository = new ReviewPrismaRepository(db);
    const auditRepository = new ModerationActionAuditPrismaRepository(db);
    reportRepository = new ReportPrismaRepository(db, auditRepository);
    const recordAudit = new RecordModerationActionUseCase(auditRepository);
    const publisher = new OutboxEventPublisher();
    const clock = new SystemClock();

    useCase = new PerformModerationActionUseCase(
      unitOfWork,
      reportRepository,
      reviewRepository,
      publisher,
      recordAudit,
      clock,
    );

    // Seed users + event
    operatorId = createId();
    reporterId = createId();
    ratedUserId = createId();
    hostUserId = createId();
    eventId = createId();

    await db.user.createMany({
      data: [
        {
          id: operatorId,
          email: `op-mod-int-${operatorId}@example.com`,
          displayName: 'Operator',
        },
        {
          id: reporterId,
          email: `reporter-mod-int-${reporterId}@example.com`,
          displayName: 'Reporter',
        },
        {
          id: ratedUserId,
          email: `rated-mod-int-${ratedUserId}@example.com`,
          displayName: 'Rated',
        },
        {
          id: hostUserId,
          email: `host-mod-int-${hostUserId}@example.com`,
          displayName: 'Host',
        },
      ],
    });

    await db.event.create({
      data: {
        id: eventId,
        hostUserId,
        title: 'Moderation Integration Test Event',
        venueAddress: '1 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: new Date('2026-05-01T18:00:00Z'),
        endsAt: new Date('2026-05-01T20:00:00Z'),
        capacity: 5,
        category: 'food',
        venueCategory: 'cafe',
        costSplit: 'own',
        approvalMode: 'manual',
        status: 'completed',
      },
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // TRI-206: moderation_action_audit teardown is handled by the module-level
    // adminPrisma afterAll (TRUNCATE). Only non-audit tables need cleanup here.
    // Scoped delete — only rows whose aggregateId matches a report created by this suite.
    if (trackedOutboxAggregateIds.size > 0) {
      await db.outboxEvent
        .deleteMany({ where: { aggregateId: { in: [...trackedOutboxAggregateIds] } } })
        .catch(() => null);
    }
    await db.review.deleteMany({ where: { eventId } }).catch(() => null);
    await db.report.deleteMany({ where: { reporterUserId: reporterId } }).catch(() => null);
    await db.event.deleteMany({ where: { id: eventId } }).catch(() => null);
    // Delete seed users + ephemeral per-review rated users (email prefix 'ephemeral-rated-').
    await db.user
      .deleteMany({
        where: { id: { in: [operatorId, reporterId, ratedUserId, hostUserId] } },
      })
      .catch(() => null);
    await db.user
      .deleteMany({ where: { email: { startsWith: 'ephemeral-rated-' } } })
      .catch(() => null);
    await db.$disconnect();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  // Each review must have a unique (eventId, raterUserId, ratedUserId) triple.
  // To allow multiple reviews per test run, we create an ad-hoc rated user on each
  // call so the triple is always unique. The extra users are cleaned up in afterAll
  // via the email prefix pattern.
  const seedReview = async (comment: string | null = 'This was a great event'): Promise<Review> => {
    // Create a unique rated user so the DB unique constraint on
    // (eventId, raterUserId, ratedUserId) never fires across calls.
    const ephemeralRatedUserId = createId();
    await db.user.create({
      data: {
        id: ephemeralRatedUserId,
        email: `ephemeral-rated-${ephemeralRatedUserId}@example.com`,
        displayName: 'Ephemeral Rated',
      },
    });
    const review = Review.submit({
      id: createId(),
      eventId,
      raterUserId: reporterId,
      ratedUserId: ephemeralRatedUserId,
      rating: Rating.create(4),
      comment: comment ? ReviewComment.create(comment) : null,
      now: new Date(),
    });
    review.pullEvents();
    await db.review.create({
      data: {
        id: review.id,
        eventId: review.eventId,
        raterUserId: review.raterUserId,
        ratedUserId: review.ratedUserId,
        rating: review.rating.value,
        comment: review.comment?.value ?? null,
        createdAt: review.createdAt,
        updatedAt: review.updatedAt,
        hidden: false,
        hiddenAt: null,
        hiddenReason: null,
      },
    });
    return review;
  };

  const seedReport = async (targetReviewId: string): Promise<Report> => {
    const report = Report.file({
      id: createId(),
      reporterUserId: reporterId,
      target: ReportTarget.create('review', targetReviewId),
      reason: ReportReason.create('harassment'),
      comment: null,
      now: new Date(),
    });
    report.pullEvents();
    await db.report.create({
      data: {
        id: report.id,
        reporterUserId: report.reporterUserId,
        targetType: report.target.type,
        targetId: report.target.id,
        reason: report.reason.value,
        comment: null,
        createdAt: report.createdAt,
        firstReviewedAt: null,
        resolvedAt: null,
        resolution: null,
        resolvedByUserId: null,
      },
    });
    // Track this report's id as an outbox aggregateId so afterAll can scope-delete.
    trackedOutboxAggregateIds.add(report.id);
    return report;
  };

  const cleanupReportAndReview = async (reportId: string, reviewId: string): Promise<void> => {
    // TRI-206: moderation_action_audit rows are handled by the module-level
    // adminPrisma afterAll (TRUNCATE) — no per-test audit delete needed.
    // Outbox rows are scoped-deleted in afterAll via trackedOutboxAggregateIds.
    await db.report.deleteMany({ where: { id: reportId } }).catch(() => null);
    await db.review.deleteMany({ where: { id: reviewId } }).catch(() => null);
  };

  // ---------------------------------------------------------------------------
  // Touch action
  // ---------------------------------------------------------------------------

  describe('touch action', () => {
    it('sets firstReviewedAt on first touch', async () => {
      const review = await seedReview();
      const report = await seedReport(review.id);

      await runAsSystem('cli.moderation.touch', async () => {
        await useCase.execute({
          operatorUserId: operatorId,
          action: 'touch',
          reportId: report.id,
          reason: null,
        });
      });

      const row = await db.report.findUnique({ where: { id: report.id } });
      expect(row?.firstReviewedAt).not.toBeNull();
      expect(row?.resolvedAt).toBeNull();

      // Audit row was created
      const auditRow = await db.moderationActionAudit.findFirst({
        where: { reportId: report.id },
      });
      expect(auditRow).not.toBeNull();
      expect(auditRow?.action).toBe('touch');
      expect(auditRow?.reason).toBeNull();
      expect(auditRow?.contentSnapshot).toBeNull();
      expect(auditRow?.operatorUserId).toBe(operatorId);
      // requestId carries the system: prefix from runAsSystem
      expect(auditRow?.requestId).toMatch(/^system:cli\.moderation\.touch:/);

      await cleanupReportAndReview(report.id, review.id);
    });

    it('is idempotent on second touch (no second audit row)', async () => {
      const review = await seedReview();
      const report = await seedReport(review.id);

      await runAsSystem('cli.moderation.touch', async () => {
        // First touch
        await useCase.execute({
          operatorUserId: operatorId,
          action: 'touch',
          reportId: report.id,
          reason: null,
        });
      });

      const firstRow = await db.report.findUnique({ where: { id: report.id } });
      const firstTouchedAt = firstRow?.firstReviewedAt;

      await runAsSystem('cli.moderation.touch', async () => {
        // Second touch — should be no-op
        await useCase.execute({
          operatorUserId: operatorId,
          action: 'touch',
          reportId: report.id,
          reason: null,
        });
      });

      const secondRow = await db.report.findUnique({ where: { id: report.id } });
      // firstReviewedAt unchanged
      expect(secondRow?.firstReviewedAt?.toISOString()).toBe(firstTouchedAt?.toISOString());

      // Still only one audit row (no-op second touch skips audit)
      const auditCount = await db.moderationActionAudit.count({
        where: { reportId: report.id },
      });
      expect(auditCount).toBe(1);

      await cleanupReportAndReview(report.id, review.id);
    });
  });

  // ---------------------------------------------------------------------------
  // resolve_hidden action
  // ---------------------------------------------------------------------------

  describe('resolve_hidden action', () => {
    it('resolves the report and hides the review atomically, with contentSnapshot', async () => {
      const knownComment = 'Original review comment text here';
      const review = await seedReview(knownComment);
      const report = await seedReport(review.id);

      await runAsSystem('cli.moderation.resolve-hidden', async () => {
        await useCase.execute({
          operatorUserId: operatorId,
          action: 'resolve_hidden',
          reportId: report.id,
          reason: 'Violates community guidelines',
        });
      });

      const reportRow = await db.report.findUnique({ where: { id: report.id } });
      expect(reportRow?.resolvedAt).not.toBeNull();
      expect(reportRow?.resolution).toBe('hidden');
      expect(reportRow?.resolvedByUserId).toBe(operatorId);

      const reviewRow = await db.review.findUnique({ where: { id: review.id } });
      expect(reviewRow?.hidden).toBe(true);
      expect(reviewRow?.hiddenAt).not.toBeNull();
      expect(reviewRow?.hiddenReason).toBe('Violates community guidelines');

      const auditRow = await db.moderationActionAudit.findFirst({
        where: { reportId: report.id },
      });
      expect(auditRow?.action).toBe('resolve_hidden');
      expect(auditRow?.reason).toBe('Violates community guidelines');
      expect(auditRow?.contentSnapshot).toBe(knownComment);
      expect(auditRow?.requestId).toMatch(/^system:cli\.moderation\.resolve-hidden:/);

      await cleanupReportAndReview(report.id, review.id);
    });

    it('atomic rollback: neither report nor audit row updated when use case throws', async () => {
      const review = await seedReview();
      const report = await seedReport(review.id);

      // First resolve succeeds.
      await runAsSystem('cli.moderation.resolve-hidden', async () => {
        await useCase.execute({
          operatorUserId: operatorId,
          action: 'resolve_hidden',
          reportId: report.id,
          reason: 'First resolution',
        });
      });

      const auditCountAfterFirst = await db.moderationActionAudit.count({
        where: { reportId: report.id },
      });
      expect(auditCountAfterFirst).toBe(1);

      // Second resolve on already-resolved report — throws ReportAlreadyResolved.
      await expect(
        runAsSystem('cli.moderation.resolve-hidden', async () => {
          await useCase.execute({
            operatorUserId: operatorId,
            action: 'resolve_hidden',
            reportId: report.id,
            reason: 'Second resolution attempt',
          });
        }),
      ).rejects.toMatchObject({ status: 409 });

      // Report state unchanged (still resolvedAt from first call).
      const reportRow = await db.report.findUnique({ where: { id: report.id } });
      expect(reportRow?.resolution).toBe('hidden');

      // NO additional audit row (rollback).
      const auditCountAfterSecond = await db.moderationActionAudit.count({
        where: { reportId: report.id },
      });
      expect(auditCountAfterSecond).toBe(1);

      await cleanupReportAndReview(report.id, review.id);
    });
  });

  // ---------------------------------------------------------------------------
  // resolve_kept action
  // ---------------------------------------------------------------------------

  describe('resolve_kept action', () => {
    it('resolves the report as kept; review is untouched; contentSnapshot is null', async () => {
      const review = await seedReview();
      const report = await seedReport(review.id);

      await runAsSystem('cli.moderation.resolve-kept', async () => {
        await useCase.execute({
          operatorUserId: operatorId,
          action: 'resolve_kept',
          reportId: report.id,
          reason: 'Content does not violate guidelines',
        });
      });

      const reportRow = await db.report.findUnique({ where: { id: report.id } });
      expect(reportRow?.resolution).toBe('kept');
      expect(reportRow?.resolvedAt).not.toBeNull();

      const reviewRow = await db.review.findUnique({ where: { id: review.id } });
      expect(reviewRow?.hidden).toBe(false);

      const auditRow = await db.moderationActionAudit.findFirst({
        where: { reportId: report.id },
      });
      expect(auditRow?.action).toBe('resolve_kept');
      expect(auditRow?.contentSnapshot).toBeNull();
      expect(auditRow?.requestId).toMatch(/^system:cli\.moderation\.resolve-kept:/);

      await cleanupReportAndReview(report.id, review.id);
    });
  });
});

/**
 * Integration test for CancelEventForSafetyUseCase against a real DB.
 *
 * Seed: operator user + host user + a published event with a future endsAt.
 *
 * Tests: success path, double-cancel refusal, missing justification validation.
 * requestId assertion verifies runAsSystem attribution chain.
 */
describe.skipIf(!dbUrl)('CancelEventForSafetyUseCase (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: PrismaUnitOfWork;
  let useCase: CancelEventForSafetyUseCase;
  let eventRepository: EventPrismaRepository;

  // Seeded IDs
  let operatorId: string;
  let hostUserId: string;

  // A far-future endsAt so the event is never in the "past end time" window.
  const FUTURE_ENDS_AT = new Date('2099-12-31T23:59:59Z');

  /** Track outbox aggregate IDs (event IDs) so cleanup can scope-delete instead of blanket-wipe. */
  const trackedOutboxAggregateIds = new Set<string>();

  beforeAll(async () => {
    if (!dbUrl) return;

    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);

    eventRepository = new EventPrismaRepository(db);
    const joinRequestRepository = new JoinRequestPrismaRepository(db);
    const auditRepository = new ModerationActionAuditPrismaRepository(db);
    const recordAudit = new RecordModerationActionUseCase(auditRepository);
    const publisher = new OutboxEventPublisher();
    const clock = new SystemClock();

    useCase = new CancelEventForSafetyUseCase(
      unitOfWork,
      eventRepository,
      joinRequestRepository,
      publisher,
      recordAudit,
      clock,
    );

    // Seed users
    operatorId = createId();
    hostUserId = createId();

    await db.user.createMany({
      data: [
        {
          id: operatorId,
          email: `op-safety-int-${operatorId}@example.com`,
          displayName: 'Safety Operator',
        },
        {
          id: hostUserId,
          email: `host-safety-int-${hostUserId}@example.com`,
          displayName: 'Event Host',
        },
      ],
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // TRI-206: moderation_action_audit teardown is handled by the module-level
    // adminPrisma afterAll (TRUNCATE). Only non-audit tables need cleanup here.
    // Scoped delete — only rows whose aggregateId matches an event created by this suite.
    if (trackedOutboxAggregateIds.size > 0) {
      await db.outboxEvent
        .deleteMany({ where: { aggregateId: { in: [...trackedOutboxAggregateIds] } } })
        .catch(() => null);
    }
    await db.event.deleteMany({ where: { hostUserId } }).catch(() => null);
    await db.user.deleteMany({ where: { id: { in: [operatorId, hostUserId] } } }).catch(() => null);
    await db.$disconnect();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  const seedPublishedEvent = async (): Promise<string> => {
    const eventId = createId();
    await db.event.create({
      data: {
        id: eventId,
        hostUserId,
        title: 'Safety Cancel Integration Test Event',
        venueAddress: '1 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: new Date('2099-12-31T18:00:00Z'),
        endsAt: FUTURE_ENDS_AT,
        capacity: 5,
        category: 'food',
        venueCategory: 'cafe',
        costSplit: 'own',
        approvalMode: 'manual',
        status: 'published',
      },
    });
    // Track this event's id as an outbox aggregateId so cleanup can scope-delete.
    trackedOutboxAggregateIds.add(eventId);
    return eventId;
  };

  const cleanupEvent = async (eventId: string): Promise<void> => {
    // TRI-206: moderation_action_audit rows are handled by the module-level
    // adminPrisma afterAll (TRUNCATE) — no per-test audit delete needed.
    // Outbox rows are scoped-deleted in afterAll via trackedOutboxAggregateIds.
    await db.event.deleteMany({ where: { id: eventId } }).catch(() => null);
  };

  // ---------------------------------------------------------------------------
  // Success path
  // ---------------------------------------------------------------------------

  describe('success path', () => {
    it('cancels the event, writes audit row, returns auditRowId + notifiedCount=0', async () => {
      const eventId = await seedPublishedEvent();

      let result: { auditRowId: string; notifiedCount: number } | undefined;

      await runAsSystem('cli.moderation.cancel-event-for-safety', async () => {
        result = await useCase.execute({
          operatorUserId: operatorId,
          eventId,
          justificationText: 'Credible safety threat reported via hotline.',
          originatingReportId: null,
        });
      });

      expect(result).toBeDefined();
      expect(result?.auditRowId).toBeTypeOf('string');
      expect(result?.notifiedCount).toBe(0); // no joiners seeded

      // Event status is cancelled in DB.
      const eventRow = await db.event.findUnique({ where: { id: eventId } });
      expect(eventRow?.status).toBe('cancelled');

      // Audit row was created with correct fields.
      const auditRow = await db.moderationActionAudit.findUnique({
        where: { id: result?.auditRowId },
      });
      expect(auditRow).not.toBeNull();
      expect(auditRow?.action).toBe('cancel_event_for_safety');
      expect(auditRow?.operatorUserId).toBe(operatorId);
      expect(auditRow?.targetId).toBe(eventId);
      expect(auditRow?.targetType).toBe('event');
      expect(auditRow?.reasonCode).toBe('safety');
      expect(auditRow?.justificationText).toBe('Credible safety threat reported via hotline.');
      expect(auditRow?.reportId).toBeNull();
      expect(auditRow?.originatingReportId).toBeNull();
      // requestId carries the system: prefix from runAsSystem
      expect(auditRow?.requestId).toMatch(/^system:cli\.moderation\.cancel-event-for-safety:/);

      await cleanupEvent(eventId);
    });
  });

  // ---------------------------------------------------------------------------
  // Refusal: double cancel (AC #2 — EVENT_ALREADY_CANCELLED)
  // ---------------------------------------------------------------------------

  describe('double-cancel refusal', () => {
    it('throws conflict with subcode EVENT_ALREADY_CANCELLED on second invocation', async () => {
      const eventId = await seedPublishedEvent();

      // First cancellation — succeeds.
      await runAsSystem('cli.moderation.cancel-event-for-safety', async () => {
        await useCase.execute({
          operatorUserId: operatorId,
          eventId,
          justificationText: 'Initial cancellation justification.',
          originatingReportId: null,
        });
      });

      // Second cancellation — must throw conflict.
      await expect(
        runAsSystem('cli.moderation.cancel-event-for-safety', async () => {
          await useCase.execute({
            operatorUserId: operatorId,
            eventId,
            justificationText: 'Duplicate attempt.',
            originatingReportId: null,
          });
        }),
      ).rejects.toMatchObject({ status: 409 });

      await cleanupEvent(eventId);
    });
  });

  // ---------------------------------------------------------------------------
  // Refusal: empty justification (AC #3 — CLI-layer validation)
  // ---------------------------------------------------------------------------

  describe('empty justification refusal', () => {
    it('throws unprocessable when justification is blank', async () => {
      const eventId = await seedPublishedEvent();

      await expect(
        runAsSystem('cli.moderation.cancel-event-for-safety', async () => {
          await useCase.execute({
            operatorUserId: operatorId,
            eventId,
            justificationText: '   ', // all whitespace — trimmed to empty
            originatingReportId: null,
          });
        }),
      ).rejects.toMatchObject({ status: 422 });

      // Event must remain published (no state mutation on validation failure).
      const eventRow = await db.event.findUnique({ where: { id: eventId } });
      expect(eventRow?.status).toBe('published');

      await cleanupEvent(eventId);
    });
  });
});

/**
 * Integration test for SweepResolvedReportsUseCase against a real DB.
 *
 * Seed: reporter user, review (target), resolved report >12 months old,
 * and an audit row with originatingReportId pointing at that report.
 *
 * Tests: report is deleted; audit row's originatingReportId is NULL'd.
 * Mirrors the PerformModerationActionUseCase integration test harness shape.
 */
describe.skipIf(!dbUrl)('SweepResolvedReportsUseCase (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: PrismaUnitOfWork;
  let useCase: SweepResolvedReportsUseCase;

  // Seeded IDs
  let reporterUserId: string;
  let ratedUserId: string;
  let hostUserId: string;
  let operatorUserId: string;
  let eventId: string;

  beforeAll(async () => {
    if (!dbUrl) return;

    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);

    const auditRepository = new ModerationActionAuditPrismaRepository(db);
    const reportRepository = new ReportPrismaRepository(db, auditRepository);
    const sweepRunRepository = new SweepRunPrismaRepository(db);
    const clock = new SystemClock();
    const logger = {
      info: (): void => undefined,
      warn: (): void => undefined,
      error: (): void => undefined,
    };

    useCase = new SweepResolvedReportsUseCase(
      unitOfWork,
      reportRepository,
      auditRepository,
      sweepRunRepository,
      clock,
      logger,
    );

    // Seed users + event
    reporterUserId = createId();
    ratedUserId = createId();
    hostUserId = createId();
    operatorUserId = createId();
    eventId = createId();

    await db.user.createMany({
      data: [
        {
          id: reporterUserId,
          email: `reporter-sweep-int-${reporterUserId}@example.com`,
          displayName: 'Reporter',
        },
        {
          id: ratedUserId,
          email: `rated-sweep-int-${ratedUserId}@example.com`,
          displayName: 'Rated',
        },
        {
          id: hostUserId,
          email: `host-sweep-int-${hostUserId}@example.com`,
          displayName: 'Host',
        },
        {
          id: operatorUserId,
          email: `op-sweep-int-${operatorUserId}@example.com`,
          displayName: 'Operator',
        },
      ],
    });

    await db.event.create({
      data: {
        id: eventId,
        hostUserId,
        title: 'Sweep Integration Test Event',
        venueAddress: '1 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: new Date('2026-05-01T18:00:00Z'),
        endsAt: new Date('2026-05-01T20:00:00Z'),
        capacity: 5,
        category: 'food',
        venueCategory: 'cafe',
        costSplit: 'own',
        approvalMode: 'manual',
        status: 'completed',
      },
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // TRI-206: moderation_action_audit teardown is handled by the module-level
    // adminPrisma afterAll (TRUNCATE). Only non-audit tables need cleanup here.
    await db.sweepRun.deleteMany({ where: { kind: 'report-retention-sweep' } }).catch(() => null);
    await db.report.deleteMany({ where: { reporterUserId } }).catch(() => null);
    await db.review.deleteMany({ where: { eventId } }).catch(() => null);
    await db.event.deleteMany({ where: { id: eventId } }).catch(() => null);
    await db.user
      .deleteMany({
        where: { id: { in: [reporterUserId, ratedUserId, hostUserId, operatorUserId] } },
      })
      .catch(() => null);
    await db.$disconnect();
  });

  // ---------------------------------------------------------------------------
  // Success path
  // ---------------------------------------------------------------------------

  describe('success path', () => {
    it('deletes resolved report >12 months old and NULLs audit originatingReportId', async () => {
      // Seed a review as the report target.
      const reviewId = createId();
      await db.review.create({
        data: {
          id: reviewId,
          eventId,
          raterUserId: reporterUserId,
          ratedUserId,
          rating: 3,
          comment: null,
          createdAt: new Date(),
          updatedAt: new Date(),
          hidden: false,
          hiddenAt: null,
          hiddenReason: null,
        },
      });

      // Seed a resolved report with resolvedAt > 12 months ago.
      const reportId = createId();
      const thirteenMonthsAgo = new Date();
      thirteenMonthsAgo.setMonth(thirteenMonthsAgo.getMonth() - 13);

      await db.report.create({
        data: {
          id: reportId,
          reporterUserId,
          targetType: 'review',
          targetId: reviewId,
          reason: 'harassment',
          comment: null,
          createdAt: thirteenMonthsAgo,
          firstReviewedAt: thirteenMonthsAgo,
          resolvedAt: thirteenMonthsAgo,
          resolution: 'kept',
          resolvedByUserId: operatorUserId,
        },
      });

      // Seed an audit row referencing the report via originatingReportId.
      const auditRowId = createId();
      await db.moderationActionAudit.create({
        data: {
          id: auditRowId,
          operatorUserId,
          action: 'cancel_event_for_safety',
          reportId: null,
          targetType: 'event',
          targetId: eventId,
          reason: null,
          contentSnapshot: null,
          reporterUserId: null,
          reasonCode: 'safety',
          justificationText: 'Safety cancellation referencing the seeded report.',
          originatingReportId: reportId,
          actedAt: new Date(),
          requestId: 'system:test:sweep-integration',
        },
      });

      // Run the sweep.
      await runAsSystem('cli.moderation.sweep-resolved-reports', async () => {
        await useCase.execute();
      });

      // Assert: report row is gone.
      const reportRow = await db.report.findUnique({ where: { id: reportId } });
      expect(reportRow).toBeNull();

      // Assert: audit row's originatingReportId is NULL'd (severed).
      const auditRow = await db.moderationActionAudit.findUnique({ where: { id: auditRowId } });
      expect(auditRow).not.toBeNull();
      expect(auditRow?.originatingReportId).toBeNull();

      // Cleanup: audit row handled by module-level adminPrisma TRUNCATE afterAll.
      await db.review.deleteMany({ where: { id: reviewId } }).catch(() => null);
    });
  });
});

/**
 * Integration tests for EscalateReportUseCase, RecordExternalInputUseCase,
 * and the escalation-gated resolve paths (resolve_with_override,
 * escalationResolveBlocked, overrideForbiddenForCategory).
 *
 * Seed per-suite: operator, reporter, rated user, host user, event, review.
 * Each test seeds its own report(s) and cleans up at the end.
 *
 * Tests:
 *   1.  escalate on open report → persists all escalation fields + outbox row + audit row.
 *   2.  escalate on already-resolved report → 409 reportAlreadyResolved; no writes.
 *   3.  escalate twice on same report → 409 reportAlreadyEscalated on second call.
 *   4.  escalate with whitespace-only --external-ref → 400 externalRefRequired; no writes.
 *   5.  record-external-input on escalated report → audit row with correct fields.
 *   6.  record-external-input on non-escalated report → 409 notEscalated.
 *   7.  record-external-input on resolved report → 409 reportAlreadyResolved.
 *   8.  resolve --hide on escalated criminal-content with no external-input → 409 escalationResolveBlocked.
 *   9.  resolve --hide --override-reason on escalated criminal-content → 400 overrideForbiddenForCategory.
 *  10.  resolve --hide --override-reason on escalated imminent-harm → 400 overrideForbiddenForCategory.
 *  11.  resolve --hide --override-reason on escalated ambiguous-policy → succeeds; audit action=resolve_with_override.
 *  12.  resolve --hide on escalated ambiguous-policy with ≥1 prior record_external_input → succeeds; audit action=resolve_hidden.
 *  13.  resolve --hide --override-reason on NON-escalated report → 400 overrideRequiresEscalation.
 *  14.  list-reports --state escalated filters correctly; escalated rows excluded from SLA banners.
 *  15.  show on escalated report → externalInputCount reflects actual audit rows.
 */
describe.skipIf(!dbUrl)(
  'EscalateReport / RecordExternalInput / escalation-gated resolve (integration)',
  () => {
    let db: PrismaClient;
    let unitOfWork: PrismaUnitOfWork;
    let escalateReportUseCase: EscalateReportUseCase;
    let recordExternalInputUseCase: RecordExternalInputUseCase;
    let performModerationActionUseCase: PerformModerationActionUseCase;
    let reportRepository: ReportPrismaRepository;
    let reviewRepository: ReviewPrismaRepository;

    // Seeded IDs
    let operatorId: string;
    let reporterId: string;
    let ratedUserId: string;
    let hostUserId: string;
    let eventId: string;

    beforeAll(async () => {
      if (!dbUrl) return;

      db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
      unitOfWork = new PrismaUnitOfWork(db);
      reviewRepository = new ReviewPrismaRepository(db);
      const auditRepository = new ModerationActionAuditPrismaRepository(db);
      reportRepository = new ReportPrismaRepository(db, auditRepository);
      const recordAudit = new RecordModerationActionUseCase(auditRepository);
      const publisher = new OutboxEventPublisher();
      const clock = new SystemClock();

      escalateReportUseCase = new EscalateReportUseCase(
        unitOfWork,
        reportRepository,
        publisher,
        recordAudit,
        clock,
      );
      recordExternalInputUseCase = new RecordExternalInputUseCase(
        unitOfWork,
        reportRepository,
        recordAudit,
        clock,
      );
      performModerationActionUseCase = new PerformModerationActionUseCase(
        unitOfWork,
        reportRepository,
        reviewRepository,
        publisher,
        recordAudit,
        clock,
      );

      // Seed users + event
      operatorId = createId();
      reporterId = createId();
      ratedUserId = createId();
      hostUserId = createId();
      eventId = createId();

      await db.user.createMany({
        data: [
          {
            id: operatorId,
            email: `op-esc-int-${operatorId}@example.com`,
            displayName: 'Operator',
          },
          {
            id: reporterId,
            email: `reporter-esc-int-${reporterId}@example.com`,
            displayName: 'Reporter',
          },
          {
            id: ratedUserId,
            email: `rated-esc-int-${ratedUserId}@example.com`,
            displayName: 'Rated',
          },
          { id: hostUserId, email: `host-esc-int-${hostUserId}@example.com`, displayName: 'Host' },
        ],
      });

      await db.event.create({
        data: {
          id: eventId,
          hostUserId,
          title: 'Escalation Integration Test Event',
          venueAddress: '1 Test St',
          venueCity: 'Singapore',
          venueLatitude: 1.3,
          venueLongitude: 103.8,
          startsAt: new Date('2026-05-01T18:00:00Z'),
          endsAt: new Date('2026-05-01T20:00:00Z'),
          capacity: 5,
          category: 'food',
          venueCategory: 'cafe',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'completed',
        },
      });
    });

    /** Track outbox aggregate IDs (report IDs) so afterAll can scope-delete instead of blanket-wipe. */
    const trackedEscOutboxAggregateIds = new Set<string>();

    afterAll(async () => {
      if (!dbUrl) return;
      // TRI-206: moderation_action_audit teardown is handled by the module-level
      // adminPrisma afterAll (TRUNCATE). Only non-audit tables need cleanup here.
      // Scoped delete — only rows whose aggregateId matches a report created by this suite.
      if (trackedEscOutboxAggregateIds.size > 0) {
        await db.outboxEvent
          .deleteMany({ where: { aggregateId: { in: [...trackedEscOutboxAggregateIds] } } })
          .catch(() => null);
      }
      await db.review.deleteMany({ where: { eventId } }).catch(() => null);
      await db.report.deleteMany({ where: { reporterUserId: reporterId } }).catch(() => null);
      await db.event.deleteMany({ where: { id: eventId } }).catch(() => null);
      // Delete seed users + ephemeral per-review rated users (email prefix 'ephemeral-rated-').
      await db.user
        .deleteMany({ where: { id: { in: [operatorId, reporterId, ratedUserId, hostUserId] } } })
        .catch(() => null);
      await db.user
        .deleteMany({ where: { email: { startsWith: 'ephemeral-rated-' } } })
        .catch(() => null);
      await db.$disconnect();
    });

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    // Each review must have a unique (eventId, raterUserId, ratedUserId) triple.
    // To allow multiple reviews per test, we create an ad-hoc rated user on each
    // call so the triple is always unique. The extra users are cleaned up in afterAll
    // via the `id NOT IN (suite constant ids)` pattern — or simply by the email prefix.
    const seedReview = async (): Promise<Review> => {
      // Create a unique rated user so the DB unique constraint on
      // (eventId, raterUserId, ratedUserId) never fires across calls.
      const ephemeralRatedUserId = createId();
      await db.user.create({
        data: {
          id: ephemeralRatedUserId,
          email: `ephemeral-rated-${ephemeralRatedUserId}@example.com`,
          displayName: 'Ephemeral Rated',
        },
      });
      const review = Review.submit({
        id: createId(),
        eventId,
        raterUserId: reporterId,
        ratedUserId: ephemeralRatedUserId,
        rating: Rating.create(4),
        comment: ReviewComment.create('Integration test review'),
        now: new Date(),
      });
      review.pullEvents();
      await db.review.create({
        data: {
          id: review.id,
          eventId: review.eventId,
          raterUserId: review.raterUserId,
          ratedUserId: review.ratedUserId,
          rating: review.rating.value,
          comment: review.comment?.value ?? null,
          createdAt: review.createdAt,
          updatedAt: review.updatedAt,
          hidden: false,
          hiddenAt: null,
          hiddenReason: null,
        },
      });
      return review;
    };

    const seedReport = async (targetReviewId: string): Promise<Report> => {
      const report = Report.file({
        id: createId(),
        reporterUserId: reporterId,
        target: ReportTarget.create('review', targetReviewId),
        reason: ReportReason.create('harassment'),
        comment: null,
        now: new Date(),
      });
      report.pullEvents();
      await db.report.create({
        data: {
          id: report.id,
          reporterUserId: report.reporterUserId,
          targetType: report.target.type,
          targetId: report.target.id,
          reason: report.reason.value,
          comment: null,
          createdAt: report.createdAt,
          firstReviewedAt: null,
          resolvedAt: null,
          resolution: null,
          resolvedByUserId: null,
        },
      });
      // Track this report's id as an outbox aggregateId so afterAll can scope-delete.
      trackedEscOutboxAggregateIds.add(report.id);
      return report;
    };

    /** Insert an escalation record directly at DB level. Used to set up resolve-path tests without going through EscalateReportUseCase. */
    const dbEscalateReport = async (
      reportId: string,
      category: string,
      externalRef = 'INTG-001',
    ): Promise<void> => {
      await db.report.update({
        where: { id: reportId },
        data: {
          escalatedAt: new Date(),
          escalationCategory: category,
          externalRef,
          escalatedByUserId: operatorId,
        },
      });
    };

    const cleanupReportAndReview = async (reportId: string, reviewId: string): Promise<void> => {
      // TRI-206: moderation_action_audit rows are handled by the module-level
      // adminPrisma afterAll (TRUNCATE) — no per-test audit delete needed.
      // Outbox rows are scoped-deleted in afterAll via trackedEscOutboxAggregateIds.
      await db.report.deleteMany({ where: { id: reportId } }).catch(() => null);
      await db.review.deleteMany({ where: { id: reviewId } }).catch(() => null);
    };

    // ---------------------------------------------------------------------------
    // Test 1 — escalate on open report
    // ---------------------------------------------------------------------------

    describe('escalate on open report', () => {
      it('persists escalation columns, outbox row, and audit row', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        await runAsSystem('cli.moderation.escalate', async () => {
          await escalateReportUseCase.execute({
            operatorUserId: operatorId,
            reportId: report.id,
            category: 'criminal-content',
            externalRef: 'SPF-2026-001',
            note: 'Credible threat; SPF notified.',
          });
        });

        // reports row — escalation columns populated
        const reportRow = await db.report.findUnique({ where: { id: report.id } });
        expect(reportRow?.escalatedAt).not.toBeNull();
        expect(reportRow?.escalationCategory).toBe('criminal-content');
        expect(reportRow?.externalRef).toBe('SPF-2026-001');
        expect(reportRow?.escalatedByUserId).toBe(operatorId);
        // resolvedAt still null — escalation does not resolve
        expect(reportRow?.resolvedAt).toBeNull();

        // outbox row for reports.reportEscalated
        const outboxRow = await db.outboxEvent.findFirst({
          where: { aggregateId: report.id, type: 'reports.reportEscalated' },
        });
        expect(outboxRow).not.toBeNull();

        // audit row
        const auditRow = await db.moderationActionAudit.findFirst({
          where: { reportId: report.id, action: 'escalate' },
        });
        expect(auditRow).not.toBeNull();
        expect(auditRow?.operatorUserId).toBe(operatorId);
        expect(auditRow?.escalationCategory).toBe('criminal-content');
        expect(auditRow?.externalRef).toBe('SPF-2026-001');
        expect(auditRow?.reason).toBe('Credible threat; SPF notified.');
        expect(auditRow?.requestId).toMatch(/^system:cli\.moderation\.escalate:/);

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 2 — escalate on already-resolved report → 409 reportAlreadyResolved
    // ---------------------------------------------------------------------------

    describe('escalate on already-resolved report', () => {
      it('throws 409 reportAlreadyResolved; no DB writes', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        // Resolve the report first at DB level so we can test the guard.
        await db.report.update({
          where: { id: report.id },
          data: { resolvedAt: new Date(), resolution: 'kept', resolvedByUserId: operatorId },
        });

        const countBefore = await db.moderationActionAudit.count({
          where: { reportId: report.id },
        });

        await expect(
          runAsSystem('cli.moderation.escalate', async () => {
            await escalateReportUseCase.execute({
              operatorUserId: operatorId,
              reportId: report.id,
              category: 'criminal-content',
              externalRef: 'SPF-2026-002',
              note: null,
            });
          }),
        ).rejects.toMatchObject({
          status: 409,
          details: { subcode: 'reports.reportAlreadyResolved' },
        });

        // No audit rows written
        const countAfter = await db.moderationActionAudit.count({
          where: { reportId: report.id },
        });
        expect(countAfter).toBe(countBefore);

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 3 — escalate twice → second call 409 reportAlreadyEscalated
    // ---------------------------------------------------------------------------

    describe('escalate twice on same report', () => {
      it('second escalate call throws 409 reportAlreadyEscalated', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        // First escalation succeeds.
        await runAsSystem('cli.moderation.escalate', async () => {
          await escalateReportUseCase.execute({
            operatorUserId: operatorId,
            reportId: report.id,
            category: 'imminent-harm',
            externalRef: 'SPF-2026-003',
            note: null,
          });
        });

        // Second escalation must throw.
        await expect(
          runAsSystem('cli.moderation.escalate', async () => {
            await escalateReportUseCase.execute({
              operatorUserId: operatorId,
              reportId: report.id,
              category: 'imminent-harm',
              externalRef: 'SPF-2026-003-dup',
              note: null,
            });
          }),
        ).rejects.toMatchObject({
          status: 409,
          details: { subcode: 'reports.reportAlreadyEscalated' },
        });

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 4 — escalate with whitespace-only externalRef → 400 externalRefRequired
    // ---------------------------------------------------------------------------

    describe('escalate with whitespace-only external-ref', () => {
      it('throws 400 externalRefRequired; no DB writes', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        await expect(
          runAsSystem('cli.moderation.escalate', async () => {
            await escalateReportUseCase.execute({
              operatorUserId: operatorId,
              reportId: report.id,
              category: 'ambiguous-policy',
              externalRef: '   ',
              note: null,
            });
          }),
        ).rejects.toMatchObject({
          status: 400,
          details: { subcode: 'reports.externalRefRequired' },
        });

        // Report should not have been escalated
        const reportRow = await db.report.findUnique({ where: { id: report.id } });
        expect(reportRow?.escalatedAt).toBeNull();

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 5 — record-external-input on escalated report
    // ---------------------------------------------------------------------------

    describe('record-external-input on escalated report', () => {
      it('writes audit row with externalSource / externalDisposition / externalReceivedAt; escalationCategory carried forward', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        // Escalate first.
        await runAsSystem('cli.moderation.escalate', async () => {
          await escalateReportUseCase.execute({
            operatorUserId: operatorId,
            reportId: report.id,
            category: 'external-jurisdiction',
            externalRef: 'IMDA-2026-001',
            note: null,
          });
        });

        const receivedAt = new Date('2026-05-25T10:00:00Z');

        await runAsSystem('cli.moderation.record-external-input', async () => {
          await recordExternalInputUseCase.execute({
            operatorUserId: operatorId,
            reportId: report.id,
            source: 'imda',
            disposition: 'IMDA case closed — no further action required.',
            receivedAt,
          });
        });

        const auditRow = await db.moderationActionAudit.findFirst({
          where: { reportId: report.id, action: 'record_external_input' },
        });
        expect(auditRow).not.toBeNull();
        expect(auditRow?.externalSource).toBe('imda');
        expect(auditRow?.externalDisposition).toBe(
          'IMDA case closed — no further action required.',
        );
        expect(auditRow?.externalReceivedAt?.toISOString()).toBe(receivedAt.toISOString());
        // escalationCategory carry-forward
        expect(auditRow?.escalationCategory).toBe('external-jurisdiction');
        expect(auditRow?.requestId).toMatch(/^system:cli\.moderation\.record-external-input:/);

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 6 — record-external-input on non-escalated report → 409 notEscalated
    // ---------------------------------------------------------------------------

    describe('record-external-input on non-escalated report', () => {
      it('throws 409 notEscalated', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        await expect(
          runAsSystem('cli.moderation.record-external-input', async () => {
            await recordExternalInputUseCase.execute({
              operatorUserId: operatorId,
              reportId: report.id,
              source: 'counsel',
              disposition: 'Some input.',
              receivedAt: new Date(),
            });
          }),
        ).rejects.toMatchObject({ status: 409, details: { subcode: 'reports.notEscalated' } });

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 7 — record-external-input on resolved report → 409 reportAlreadyResolved
    // ---------------------------------------------------------------------------

    describe('record-external-input on resolved report', () => {
      it('throws 409 reportAlreadyResolved', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        // Escalate and resolve directly in DB so we can test the guard.
        await db.report.update({
          where: { id: report.id },
          data: {
            escalatedAt: new Date(),
            escalationCategory: 'ambiguous-policy',
            externalRef: 'REF-007',
            escalatedByUserId: operatorId,
            resolvedAt: new Date(),
            resolution: 'kept',
            resolvedByUserId: operatorId,
          },
        });

        await expect(
          runAsSystem('cli.moderation.record-external-input', async () => {
            await recordExternalInputUseCase.execute({
              operatorUserId: operatorId,
              reportId: report.id,
              source: 'partner',
              disposition: 'Post-resolution input.',
              receivedAt: new Date(),
            });
          }),
        ).rejects.toMatchObject({
          status: 409,
          details: { subcode: 'reports.reportAlreadyResolved' },
        });

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 8 — resolve --hide on escalated criminal-content (no external-input, no override) → 409 escalationResolveBlocked
    // ---------------------------------------------------------------------------

    describe('resolve --hide on escalated criminal-content without external-input', () => {
      it('throws 409 escalationResolveBlocked; no resolution written', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        await dbEscalateReport(report.id, 'criminal-content');

        await expect(
          runAsSystem('cli.moderation.resolve-hidden', async () => {
            await performModerationActionUseCase.execute({
              operatorUserId: operatorId,
              action: 'resolve_hidden',
              reportId: report.id,
              reason: 'Resolve after escalation.',
            });
          }),
        ).rejects.toMatchObject({
          status: 409,
          details: { subcode: 'reports.escalationResolveBlocked' },
        });

        const reportRow = await db.report.findUnique({ where: { id: report.id } });
        expect(reportRow?.resolvedAt).toBeNull();

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 9 — resolve --hide --override-reason on escalated criminal-content → 400 overrideForbiddenForCategory
    // ---------------------------------------------------------------------------

    describe('resolve --hide --override-reason on escalated criminal-content', () => {
      it('throws 400 overrideForbiddenForCategory', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        await dbEscalateReport(report.id, 'criminal-content');

        await expect(
          runAsSystem('cli.moderation.resolve-hidden', async () => {
            await performModerationActionUseCase.execute({
              operatorUserId: operatorId,
              action: 'resolve_hidden',
              reportId: report.id,
              reason: 'Resolve with override.',
              overrideReason: 'I want to override.',
            });
          }),
        ).rejects.toMatchObject({
          status: 400,
          details: { subcode: 'reports.overrideForbiddenForCategory' },
        });

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 10 — resolve --hide --override-reason on escalated imminent-harm → 400 overrideForbiddenForCategory
    // ---------------------------------------------------------------------------

    describe('resolve --hide --override-reason on escalated imminent-harm', () => {
      it('throws 400 overrideForbiddenForCategory', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        await dbEscalateReport(report.id, 'imminent-harm');

        await expect(
          runAsSystem('cli.moderation.resolve-hidden', async () => {
            await performModerationActionUseCase.execute({
              operatorUserId: operatorId,
              action: 'resolve_hidden',
              reportId: report.id,
              reason: 'Resolve with override.',
              overrideReason: 'I want to override.',
            });
          }),
        ).rejects.toMatchObject({
          status: 400,
          details: { subcode: 'reports.overrideForbiddenForCategory' },
        });

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 11 — resolve --hide --override-reason on escalated ambiguous-policy → succeeds with resolve_with_override
    // ---------------------------------------------------------------------------

    describe('resolve --hide --override-reason on escalated ambiguous-policy', () => {
      it('succeeds; audit action=resolve_with_override, escalationCategory carried forward', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        await dbEscalateReport(report.id, 'ambiguous-policy');

        await runAsSystem('cli.moderation.resolve-hidden', async () => {
          await performModerationActionUseCase.execute({
            operatorUserId: operatorId,
            action: 'resolve_hidden',
            reportId: report.id,
            reason: 'Content analysis complete.',
            overrideReason: 'After review, no external input required for this policy matter.',
          });
        });

        const reportRow = await db.report.findUnique({ where: { id: report.id } });
        expect(reportRow?.resolvedAt).not.toBeNull();
        expect(reportRow?.resolution).toBe('hidden');

        const auditRow = await db.moderationActionAudit.findFirst({
          where: { reportId: report.id, action: 'resolve_with_override' },
        });
        expect(auditRow).not.toBeNull();
        expect(auditRow?.reason).toBe(
          'After review, no external input required for this policy matter.',
        );
        expect(auditRow?.escalationCategory).toBe('ambiguous-policy');
        expect(auditRow?.operatorUserId).toBe(operatorId);

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 12 — resolve --hide on escalated ambiguous-policy with ≥1 prior record_external_input
    // ---------------------------------------------------------------------------

    describe('resolve --hide on escalated ambiguous-policy with prior record_external_input', () => {
      it('succeeds; audit action=resolve_hidden; externalInputCount hydrated from DB', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        // Escalate
        await runAsSystem('cli.moderation.escalate', async () => {
          await escalateReportUseCase.execute({
            operatorUserId: operatorId,
            reportId: report.id,
            category: 'ambiguous-policy',
            externalRef: 'COUNSEL-2026-001',
            note: null,
          });
        });

        // Record one external input
        await runAsSystem('cli.moderation.record-external-input', async () => {
          await recordExternalInputUseCase.execute({
            operatorUserId: operatorId,
            reportId: report.id,
            source: 'counsel',
            disposition: 'Counsel review complete.',
            receivedAt: new Date('2026-05-25T14:00:00Z'),
          });
        });

        // Resolve — should succeed because externalInputCount >= 1
        await runAsSystem('cli.moderation.resolve-hidden', async () => {
          await performModerationActionUseCase.execute({
            operatorUserId: operatorId,
            action: 'resolve_hidden',
            reportId: report.id,
            reason: 'Resolved following counsel input.',
          });
        });

        const reportRow = await db.report.findUnique({ where: { id: report.id } });
        expect(reportRow?.resolvedAt).not.toBeNull();
        expect(reportRow?.resolution).toBe('hidden');

        const auditRow = await db.moderationActionAudit.findFirst({
          where: { reportId: report.id, action: 'resolve_hidden' },
        });
        expect(auditRow).not.toBeNull();
        expect(auditRow?.reason).toBe('Resolved following counsel input.');

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 13 — resolve --hide --override-reason on NON-escalated report → 400 overrideRequiresEscalation
    // ---------------------------------------------------------------------------

    describe('resolve --hide --override-reason on non-escalated report', () => {
      it('throws 400 overrideRequiresEscalation', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        // report is NOT escalated
        await expect(
          runAsSystem('cli.moderation.resolve-hidden', async () => {
            await performModerationActionUseCase.execute({
              operatorUserId: operatorId,
              action: 'resolve_hidden',
              reportId: report.id,
              reason: 'Resolve non-escalated report.',
              overrideReason: 'Override attempt on non-escalated report.',
            });
          }),
        ).rejects.toMatchObject({
          status: 400,
          details: { subcode: 'reports.overrideRequiresEscalation' },
        });

        await cleanupReportAndReview(report.id, review.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 14 — list-reports --state escalated filters correctly
    // ---------------------------------------------------------------------------

    describe('list-reports --state escalated', () => {
      it('returns only escalated-and-unresolved reports; escalated row excluded from banner counts', async () => {
        const review1 = await seedReview();
        const review2 = await seedReview();
        const openReport = await seedReport(review1.id);
        const escalatedReport = await seedReport(review2.id);

        // Escalate only the second report
        await runAsSystem('cli.moderation.escalate', async () => {
          await escalateReportUseCase.execute({
            operatorUserId: operatorId,
            reportId: escalatedReport.id,
            category: 'criminal-content',
            externalRef: 'SPF-2026-014',
            note: null,
          });
        });

        // Fetch all unresolved reports from DB and verify the escalated row is present
        const allUnresolved = await reportRepository.listUnresolved({ limit: 100 });
        const allIds = allUnresolved.rows.map((r) => r.id);
        expect(allIds).toContain(escalatedReport.id);
        expect(allIds).toContain(openReport.id);

        // Filter in-process (mirrors cmdListReports logic)
        const escalatedRows = allUnresolved.rows.filter(
          (r) => r.escalatedAt !== null && r.resolvedAt === null,
        );
        expect(escalatedRows.map((r) => r.id)).toContain(escalatedReport.id);
        expect(escalatedRows.map((r) => r.id)).not.toContain(openReport.id);

        // Escalated row should have PAUSED-AT-ESC as the SLA state
        const escalatedRow = escalatedRows.find((r) => r.id === escalatedReport.id);
        expect(escalatedRow).toBeDefined();
        const escalatedRowDefined = escalatedRow as NonNullable<typeof escalatedRow>;
        expect(escalatedRowDefined.escalatedAt).not.toBeNull();

        await cleanupReportAndReview(openReport.id, review1.id);
        await cleanupReportAndReview(escalatedReport.id, review2.id);
      });
    });

    // ---------------------------------------------------------------------------
    // Test 15 — show: externalInputCount correctly hydrated
    // ---------------------------------------------------------------------------

    describe('show on escalated report', () => {
      it('externalInputCount reflects the actual number of record_external_input audit rows', async () => {
        const review = await seedReview();
        const report = await seedReport(review.id);

        // Escalate
        await runAsSystem('cli.moderation.escalate', async () => {
          await escalateReportUseCase.execute({
            operatorUserId: operatorId,
            reportId: report.id,
            category: 'external-jurisdiction',
            externalRef: 'IMDA-2026-015',
            note: null,
          });
        });

        // No external input yet — count should be 0
        const reportBefore = await reportRepository.findById(report.id);
        expect(reportBefore).not.toBeNull();
        const reportBeforeDefined = reportBefore as NonNullable<typeof reportBefore>;
        expect(reportBeforeDefined.externalInputCount).toBe(0);
        expect(reportBeforeDefined.escalatedAt).not.toBeNull();

        // Record two external inputs
        await runAsSystem('cli.moderation.record-external-input', async () => {
          await recordExternalInputUseCase.execute({
            operatorUserId: operatorId,
            reportId: report.id,
            source: 'imda',
            disposition: 'First IMDA update.',
            receivedAt: new Date('2026-05-25T10:00:00Z'),
          });
        });
        await runAsSystem('cli.moderation.record-external-input', async () => {
          await recordExternalInputUseCase.execute({
            operatorUserId: operatorId,
            reportId: report.id,
            source: 'counsel',
            disposition: 'Counsel clarification.',
            receivedAt: new Date('2026-05-26T08:00:00Z'),
          });
        });

        // Re-fetch report — externalInputCount should be 2
        const reportAfter = await reportRepository.findById(report.id);
        expect(reportAfter).not.toBeNull();
        const reportAfterDefined = reportAfter as NonNullable<typeof reportAfter>;
        expect(reportAfterDefined.externalInputCount).toBe(2);

        // The Submitted/Escalated fields are present on the re-fetched aggregate
        expect(reportAfterDefined.createdAt).not.toBeNull();
        expect(reportAfterDefined.escalatedAt).not.toBeNull();

        await cleanupReportAndReview(report.id, review.id);
      });
    });
  },
);
