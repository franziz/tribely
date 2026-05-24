import { describe, expect, it, vi, beforeEach } from 'vitest';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import { Review } from '../../domain/entities/review.js';
import { Rating } from '../../domain/value-objects/rating.js';
import { ReviewComment } from '../../domain/value-objects/review-comment.js';
import type {
  ReviewRepository,
  ReviewWithVisibilityContext,
} from '../../domain/repositories/review.repository.js';
import type { CheckBlockedPort } from '@/features/user-blocks/application/ports/check-blocked.port.js';
import { ListReviewsForUserUseCase } from './list-reviews-for-user.usecase.js';

const BLIND_WINDOW_MS = 14 * 24 * 60 * 60 * 1000;

const eventCompletedAt = new Date('2025-01-01T20:00:00Z');
const nowWithin = new Date(eventCompletedAt.getTime() + 24 * 60 * 60 * 1000); // within blind window
const nowAfter = new Date(eventCompletedAt.getTime() + BLIND_WINDOW_MS + 1); // after blind window

const makeClock = (now: Date): Clock => ({ now: vi.fn(() => now) });

const makeReview = (options?: {
  raterUserId?: string;
  ratedUserId?: string;
  hidden?: boolean;
  comment?: string | null;
}): Review => {
  const now = new Date('2025-01-01T12:00:00Z');
  const r = Review.submit({
    id: 'rev_001',
    eventId: 'evt_001',
    raterUserId: options?.raterUserId ?? 'user_rater',
    ratedUserId: options?.ratedUserId ?? 'user_rated',
    rating: Rating.create(4),
    comment:
      options?.comment !== undefined
        ? options.comment !== null
          ? ReviewComment.create(options.comment)
          : null
        : ReviewComment.create('Nice!'),
    now,
  });
  if (options?.hidden) {
    r.hide({ hiddenByUserId: 'mod_001', reportId: 'rpt_001', reason: 'Spam', now });
  }
  r.pullEvents();
  return r;
};

const makeRow = (
  review: Review,
  counterpartExists = false,
  completedAt = eventCompletedAt,
): ReviewWithVisibilityContext => ({
  review,
  counterpartExists,
  eventCompletedAt: completedAt,
});

const noopBlocked: CheckBlockedPort = {
  filterBlocked: vi.fn(() => Promise.resolve(new Set<string>())),
  isBlocked: vi.fn(() => Promise.resolve(false)),
};

describe('ListReviewsForUserUseCase', () => {
  let listByRatedUserSpy: ReturnType<typeof vi.fn>;
  let reviewRepo: ReviewRepository;
  let useCase: ListReviewsForUserUseCase;

  beforeEach(() => {
    listByRatedUserSpy = vi.fn(() => Promise.resolve({ rows: [], nextCursor: null }));
    reviewRepo = {
      save: vi.fn((): Promise<void> => Promise.resolve()),
      findById: vi.fn(() => Promise.resolve(null)),
      findByTriple: vi.fn(() => Promise.resolve(null)),
      findExistingTriples: vi.fn(() => Promise.resolve(new Set<string>())),
      listByRatedUser: listByRatedUserSpy,
      listWrittenBy: vi.fn(() => Promise.resolve({ rows: [], nextCursor: null })),
      aggregateForUser: vi.fn(() =>
        Promise.resolve({
          averageRating: null,
          reviewCount: 0,
          recentVisibleComments: [],
        }),
      ),
      deleteAllForUser: vi.fn(
        (_userId: string, _ctx: unknown): Promise<number> => Promise.resolve(0),
      ),
    };
  });

  it('returns visible reviews with full content', async () => {
    const review = makeReview();
    listByRatedUserSpy.mockResolvedValue({
      rows: [makeRow(review, true)], // counterpartExists=true → visible
      nextCursor: null,
    });
    useCase = new ListReviewsForUserUseCase(reviewRepo, noopBlocked, makeClock(nowWithin));

    const result = await useCase.execute({ viewerId: 'user_rated', targetUserId: 'user_rated' });
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0]?.rating).toBe(4);
    expect(result.rows[0]?.comment).toBe('Nice!');
    expect(result.rows[0]?.hiddenForMutualWindow).toBe(false);
    expect(result.rows[0]?.hidden).toBe(false);
  });

  it('returns blind-mutual-pending rows with rating=null, comment=null', async () => {
    const review = makeReview();
    listByRatedUserSpy.mockResolvedValue({
      rows: [makeRow(review, false)], // no counterpart, within window
      nextCursor: null,
    });
    useCase = new ListReviewsForUserUseCase(reviewRepo, noopBlocked, makeClock(nowWithin));

    const result = await useCase.execute({ viewerId: 'user_rated', targetUserId: 'user_rated' });
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0]?.rating).toBeNull();
    expect(result.rows[0]?.comment).toBeNull();
    expect(result.rows[0]?.hiddenForMutualWindow).toBe(true);
  });

  it('excludes hidden reviews from non-author viewers', async () => {
    const review = makeReview({ hidden: true });
    listByRatedUserSpy.mockResolvedValue({
      rows: [makeRow(review, false)],
      nextCursor: null,
    });
    useCase = new ListReviewsForUserUseCase(reviewRepo, noopBlocked, makeClock(nowWithin));

    const result = await useCase.execute({ viewerId: 'user_rated', targetUserId: 'user_rated' });
    expect(result.rows).toHaveLength(0);
  });

  it('shows hidden review to the author with hidden=true flag', async () => {
    const review = makeReview({ hidden: true });
    listByRatedUserSpy.mockResolvedValue({
      rows: [makeRow(review, false)],
      nextCursor: null,
    });
    useCase = new ListReviewsForUserUseCase(reviewRepo, noopBlocked, makeClock(nowWithin));

    // Author is user_rater
    const result = await useCase.execute({ viewerId: 'user_rater', targetUserId: 'user_rated' });
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0]?.hidden).toBe(true);
    expect(result.rows[0]?.rating).toBe(4);
  });

  it('author always sees own visible review', async () => {
    const review = makeReview({ raterUserId: 'user_rater', ratedUserId: 'user_rated' });
    listByRatedUserSpy.mockResolvedValue({
      rows: [makeRow(review, false)], // no counterpart but author is viewer
      nextCursor: null,
    });
    useCase = new ListReviewsForUserUseCase(reviewRepo, noopBlocked, makeClock(nowWithin));

    const result = await useCase.execute({ viewerId: 'user_rater', targetUserId: 'user_rated' });
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0]?.rating).toBe(4); // full content
  });

  it('visible after 14-day blind window expires', async () => {
    const review = makeReview();
    listByRatedUserSpy.mockResolvedValue({
      rows: [makeRow(review, false)],
      nextCursor: null,
    });
    useCase = new ListReviewsForUserUseCase(reviewRepo, noopBlocked, makeClock(nowAfter));

    const result = await useCase.execute({ viewerId: 'user_rated', targetUserId: 'user_rated' });
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0]?.rating).toBe(4);
  });

  it('excludes blocked raters', async () => {
    const review = makeReview({ raterUserId: 'blocked_user' });
    listByRatedUserSpy.mockResolvedValue({
      rows: [makeRow(review, true)],
      nextCursor: null,
    });
    const blockedPort: CheckBlockedPort = {
      filterBlocked: vi.fn(() => Promise.resolve(new Set(['blocked_user']))),
      isBlocked: vi.fn(() => Promise.resolve(false)),
    };
    useCase = new ListReviewsForUserUseCase(reviewRepo, blockedPort, makeClock(nowWithin));

    const result = await useCase.execute({ viewerId: 'user_rated', targetUserId: 'user_rated' });
    expect(result.rows).toHaveLength(0);
  });

  it('propagates nextCursor', async () => {
    listByRatedUserSpy.mockResolvedValue({
      rows: [],
      nextCursor: 'some-cursor-token',
    });
    useCase = new ListReviewsForUserUseCase(reviewRepo, noopBlocked, makeClock(nowWithin));

    const result = await useCase.execute({ viewerId: 'viewer', targetUserId: 'user_rated' });
    expect(result.nextCursor).toBe('some-cursor-token');
  });
});
