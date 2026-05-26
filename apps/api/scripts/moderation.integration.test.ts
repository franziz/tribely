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

const dbUrl = process.env.DATABASE_URL;

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

  beforeAll(async () => {
    if (!dbUrl) return;

    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);

    reportRepository = new ReportPrismaRepository(db);
    reviewRepository = new ReviewPrismaRepository(db);
    const auditRepository = new ModerationActionAuditPrismaRepository(db);
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
    // Clean up in FK-safe order.
    await db.moderationActionAudit
      .deleteMany({
        where: {
          OR: [{ operatorUserId: operatorId }, { reporterUserId: reporterId }],
        },
      })
      .catch(() => null);
    // Outbox rows have no FK to reports/reviews — safe to leave or delete by event.
    await db.outboxEvent.deleteMany({}).catch(() => null);
    await db.review.deleteMany({ where: { eventId } }).catch(() => null);
    await db.report.deleteMany({ where: { reporterUserId: reporterId } }).catch(() => null);
    await db.event.deleteMany({ where: { id: eventId } }).catch(() => null);
    await db.user
      .deleteMany({
        where: { id: { in: [operatorId, reporterId, ratedUserId, hostUserId] } },
      })
      .catch(() => null);
    await db.$disconnect();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  const seedReview = async (comment: string | null = 'This was a great event'): Promise<Review> => {
    const review = Review.submit({
      id: createId(),
      eventId,
      raterUserId: reporterId,
      ratedUserId,
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
    return report;
  };

  const cleanupReportAndReview = async (reportId: string, reviewId: string): Promise<void> => {
    // Audit rows reference reportId — delete audit before report (no FK, but
    // keeps cleanup semantically ordered).
    await db.moderationActionAudit.deleteMany({ where: { reportId } }).catch(() => null);
    // Outbox rows are written by OutboxEventPublisher but have no FK to
    // reports or reviews — left for afterAll cleanup.
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
    // Clean up in FK-safe order.
    await db.moderationActionAudit
      .deleteMany({ where: { operatorUserId: operatorId } })
      .catch(() => null);
    await db.outboxEvent.deleteMany({}).catch(() => null);
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
    return eventId;
  };

  const cleanupEvent = async (eventId: string): Promise<void> => {
    await db.moderationActionAudit.deleteMany({ where: { targetId: eventId } }).catch(() => null);
    await db.outboxEvent.deleteMany({}).catch(() => null);
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

    const reportRepository = new ReportPrismaRepository(db);
    const auditRepository = new ModerationActionAuditPrismaRepository(db);
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
    // Clean up in FK-safe order.
    await db.sweepRun.deleteMany({ where: { kind: 'report-retention-sweep' } }).catch(() => null);
    await db.moderationActionAudit.deleteMany({ where: { operatorUserId } }).catch(() => null);
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

      // Cleanup.
      await db.moderationActionAudit.deleteMany({ where: { id: auditRowId } }).catch(() => null);
      await db.review.deleteMany({ where: { id: reviewId } }).catch(() => null);
    });
  });
});
