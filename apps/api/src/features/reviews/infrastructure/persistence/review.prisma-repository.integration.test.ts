// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import { Review } from '../../domain/entities/review.js';
import { Rating } from '../../domain/value-objects/rating.js';
import { ReviewComment } from '../../domain/value-objects/review-comment.js';
import { ReviewPrismaRepository } from './review.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

describe.skipIf(!dbUrl)('ReviewPrismaRepository — integration', () => {
  let db: PrismaClient;
  let repo: ReviewPrismaRepository;
  let uow: PrismaUnitOfWork;

  // Shared test user + event IDs seeded per-suite.
  let hostId: string;
  let guestId: string;
  // secondGuestId is used by the upsert test to avoid a unique-triple
  // conflict with the 'saves and retrieves' test, which also uses
  // (hostId, guestId) as the (rater, rated) pair.
  let secondGuestId: string;
  let eventId: string;

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    repo = new ReviewPrismaRepository(db);
    uow = new PrismaUnitOfWork(db);

    // Seed minimal User + Event rows for FK satisfaction.
    hostId = createId();
    guestId = createId();
    secondGuestId = createId();
    eventId = createId();

    await db.user.createMany({
      data: [
        { id: hostId, email: `host-rev-test-${hostId}@example.com`, displayName: 'Host' },
        { id: guestId, email: `guest-rev-test-${guestId}@example.com`, displayName: 'Guest' },
        {
          id: secondGuestId,
          email: `guest2-rev-test-${secondGuestId}@example.com`,
          displayName: 'Guest2',
        },
      ],
    });

    await db.event.create({
      data: {
        id: eventId,
        hostUserId: hostId,
        title: 'Review Test Event',
        venueAddress: '1 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: new Date('2025-01-01T18:00:00Z'),
        endsAt: new Date('2025-01-01T20:00:00Z'),
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
    await db.review.deleteMany({ where: { eventId } });
    await db.event.delete({ where: { id: eventId } });
    await db.user.deleteMany({ where: { id: { in: [hostId, guestId, secondGuestId] } } });
    await db.$disconnect();
  });

  it('saves and retrieves a review', async () => {
    const now = new Date();
    const review = Review.submit({
      id: createId(),
      eventId,
      raterUserId: hostId,
      ratedUserId: guestId,
      rating: Rating.create(4),
      comment: ReviewComment.create('Great guest!'),
      now,
    });
    review.pullEvents();

    await uow.run(async (ctx) => {
      await repo.save(review, ctx);
    });

    const loaded = await repo.findById(review.id);
    expect(loaded).not.toBeNull();
    expect(loaded?.rating.value).toBe(4);
    expect(loaded?.comment?.value).toBe('Great guest!');
    expect(loaded?.hidden).toBe(false);
  });

  it('findByTriple returns the review', async () => {
    const now = new Date();
    const review = Review.submit({
      id: createId(),
      eventId,
      raterUserId: guestId,
      ratedUserId: hostId,
      rating: Rating.create(5),
      comment: null,
      now,
    });
    review.pullEvents();

    await uow.run(async (ctx) => {
      await repo.save(review, ctx);
    });

    const found = await repo.findByTriple({
      eventId,
      raterUserId: guestId,
      ratedUserId: hostId,
    });
    expect(found).not.toBeNull();
    expect(found?.id).toBe(review.id);
  });

  it('save updates existing review (upsert)', async () => {
    const now = new Date();
    // Use secondGuestId to avoid a unique-triple conflict with the
    // 'saves and retrieves' test which already inserted (hostId, guestId).
    const review = Review.submit({
      id: createId(),
      eventId,
      raterUserId: hostId,
      ratedUserId: secondGuestId,
      rating: Rating.create(3),
      comment: null,
      now,
    });
    review.pullEvents();
    await uow.run(async (ctx) => {
      await repo.save(review, ctx);
    });

    // Edit within window.
    review.edit({
      rating: Rating.create(5),
      comment: ReviewComment.create('Updated!'),
      now: new Date(now.getTime() + 1000),
    });
    review.pullEvents();
    await uow.run(async (ctx) => {
      await repo.save(review, ctx);
    });

    const updated = await repo.findById(review.id);
    expect(updated?.rating.value).toBe(5);
    expect(updated?.comment?.value).toBe('Updated!');
  });
});
