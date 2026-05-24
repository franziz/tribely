import { describe, expect, it, vi, beforeEach } from 'vitest';
import { Review } from '../../domain/entities/review.js';
import { Rating } from '../../domain/value-objects/rating.js';
import { ReviewComment } from '../../domain/value-objects/review-comment.js';
import type { ReviewRepository } from '../../domain/repositories/review.repository.js';
import { ListReviewsWrittenByMeUseCase } from './list-reviews-written-by-me.usecase.js';

const makeReview = (options?: { hidden?: boolean }): Review => {
  const now = new Date('2025-01-01T12:00:00Z');
  const r = Review.submit({
    id: 'rev_001',
    eventId: 'evt_001',
    raterUserId: 'user_rater',
    ratedUserId: 'user_rated',
    rating: Rating.create(4),
    comment: ReviewComment.create('Good times'),
    now,
  });
  if (options?.hidden) {
    r.hide({ hiddenByUserId: 'mod_001', reportId: 'rpt_001', reason: 'Spam', now });
  }
  r.pullEvents();
  return r;
};

describe('ListReviewsWrittenByMeUseCase', () => {
  let listWrittenBySpy: ReturnType<typeof vi.fn>;
  let reviewRepo: ReviewRepository;
  let useCase: ListReviewsWrittenByMeUseCase;

  beforeEach(() => {
    listWrittenBySpy = vi.fn(() => Promise.resolve({ rows: [], nextCursor: null }));
    reviewRepo = {
      save: vi.fn((): Promise<void> => Promise.resolve()),
      findById: vi.fn(() => Promise.resolve(null)),
      findByTriple: vi.fn(() => Promise.resolve(null)),
      findExistingTriples: vi.fn(() => Promise.resolve(new Set<string>())),
      listByRatedUser: vi.fn(() => Promise.resolve({ rows: [], nextCursor: null })),
      listWrittenBy: listWrittenBySpy,
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
    useCase = new ListReviewsWrittenByMeUseCase(reviewRepo);
  });

  it('returns visible reviews with full content', async () => {
    listWrittenBySpy.mockResolvedValue({
      rows: [makeReview()],
      nextCursor: null,
    });

    const result = await useCase.execute({ raterUserId: 'user_rater' });
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0]?.rating).toBe(4);
    expect(result.rows[0]?.comment).toBe('Good times');
    expect(result.rows[0]?.hidden).toBe(false);
    expect(result.rows[0]?.hiddenAt).toBeNull();
  });

  it('includes hidden reviews with hidden=true flag', async () => {
    listWrittenBySpy.mockResolvedValue({
      rows: [makeReview({ hidden: true })],
      nextCursor: null,
    });

    const result = await useCase.execute({ raterUserId: 'user_rater' });
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0]?.hidden).toBe(true);
    expect(result.rows[0]?.hiddenAt).not.toBeNull();
    // Full content still returned (author sees their own review).
    expect(result.rows[0]?.rating).toBe(4);
  });

  it('passes cursor and limit to repository', async () => {
    await useCase.execute({ raterUserId: 'user_rater', cursor: 'some-cursor', limit: 10 });
    expect(listWrittenBySpy).toHaveBeenCalledWith(
      expect.objectContaining({ cursor: 'some-cursor', limit: 10 }),
    );
  });

  it('caps limit at 100', async () => {
    await useCase.execute({ raterUserId: 'user_rater', limit: 9999 });
    expect(listWrittenBySpy).toHaveBeenCalledWith(expect.objectContaining({ limit: 100 }));
  });
});
