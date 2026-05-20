import { describe, expect, it } from 'vitest';
import { Rating } from '../../domain/value-objects/rating.js';
import { ReviewComment } from '../../domain/value-objects/review-comment.js';
import { Review } from '../../domain/entities/review.js';
import { reviewVisibilityProjection } from './review-visibility.projection.js';

const BLIND_WINDOW_MS = 14 * 24 * 60 * 60 * 1000;

const makeReview = (hidden = false): Review => {
  const now = new Date('2025-01-01T12:00:00Z');
  const r = Review.submit({
    id: 'rev_001',
    eventId: 'evt_001',
    raterUserId: 'user_rater',
    ratedUserId: 'user_rated',
    rating: Rating.create(4),
    comment: ReviewComment.create('Good vibes!'),
    now,
  });
  if (hidden) {
    r.hide({ hiddenByUserId: 'mod_001', reportId: 'rpt_001', reason: 'Spam', now });
  }
  r.pullEvents();
  return r;
};

const eventCompletedAt = new Date('2025-01-01T18:00:00Z');
// Within blind window — 1 day after event
const nowWithin = new Date(eventCompletedAt.getTime() + 24 * 60 * 60 * 1000);
// After blind window — 15 days after event
const nowAfter = new Date(eventCompletedAt.getTime() + BLIND_WINDOW_MS + 1);

describe('reviewVisibilityProjection', () => {
  it('hidden review returns hidden regardless of viewer', () => {
    const r = makeReview(true);
    expect(
      reviewVisibilityProjection({
        review: r,
        viewerId: 'some_viewer',
        counterpartExists: true,
        eventCompletedAt,
        now: nowWithin,
      }),
    ).toBe('hidden');
  });

  it('author (raterUserId === viewerId) always sees own review as visible', () => {
    const r = makeReview();
    expect(
      reviewVisibilityProjection({
        review: r,
        viewerId: 'user_rater',
        counterpartExists: false,
        eventCompletedAt,
        now: nowWithin,
      }),
    ).toBe('visible');
  });

  it('visible when counterpartExists, within window', () => {
    const r = makeReview();
    expect(
      reviewVisibilityProjection({
        review: r,
        viewerId: 'user_rated',
        counterpartExists: true,
        eventCompletedAt,
        now: nowWithin,
      }),
    ).toBe('visible');
  });

  it('visible when 14-day window has expired (no counterpart)', () => {
    const r = makeReview();
    expect(
      reviewVisibilityProjection({
        review: r,
        viewerId: 'user_rated',
        counterpartExists: false,
        eventCompletedAt,
        now: nowAfter,
      }),
    ).toBe('visible');
  });

  it('blind-mutual-pending within window, no counterpart, third-party viewer', () => {
    const r = makeReview();
    expect(
      reviewVisibilityProjection({
        review: r,
        viewerId: 'user_rated',
        counterpartExists: false,
        eventCompletedAt,
        now: nowWithin,
      }),
    ).toBe('blind-mutual-pending');
  });

  it('blind-mutual-pending for rated user who has not written counterpart', () => {
    const r = makeReview();
    expect(
      reviewVisibilityProjection({
        review: r,
        viewerId: 'user_rated',
        counterpartExists: false,
        eventCompletedAt,
        now: new Date(eventCompletedAt.getTime() + BLIND_WINDOW_MS - 1),
      }),
    ).toBe('blind-mutual-pending');
  });

  it('exactly at 14-day boundary is visible (>= not >)', () => {
    const r = makeReview();
    const atBoundary = new Date(eventCompletedAt.getTime() + BLIND_WINDOW_MS);
    expect(
      reviewVisibilityProjection({
        review: r,
        viewerId: 'user_rated',
        counterpartExists: false,
        eventCompletedAt,
        now: atBoundary,
      }),
    ).toBe('visible');
  });
});
