import { describe, expect, it } from 'vitest';
import { Rating } from '../value-objects/rating.js';
import { ReviewComment } from '../value-objects/review-comment.js';
import { Review } from './review.js';

const makeReview = (overrides?: { comment?: ReviewComment | null; now?: Date }) => {
  const now = overrides?.now ?? new Date('2025-01-01T12:00:00Z');
  return Review.submit({
    id: 'rev_001',
    eventId: 'evt_001',
    raterUserId: 'user_rater',
    ratedUserId: 'user_rated',
    rating: Rating.create(4),
    comment:
      overrides?.comment !== undefined ? overrides.comment : ReviewComment.create('Good vibes!'),
    now,
  });
};

describe('Review.submit', () => {
  it('creates a review with correct fields', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = makeReview({ now });
    expect(r.id).toBe('rev_001');
    expect(r.rating.value).toBe(4);
    expect(r.comment?.value).toBe('Good vibes!');
    expect(r.hidden).toBe(false);
    expect(r.createdAt).toEqual(now);
  });

  it('records reviewSubmitted event with hasComment=true', () => {
    const r = makeReview();
    const events = r.pullEvents();
    expect(events).toHaveLength(1);
    expect(events[0]?.type).toBe('reviews.reviewSubmitted');
    const payload = events[0]?.payload as { hasComment: boolean; rating: number };
    expect(payload.hasComment).toBe(true);
    expect(payload.rating).toBe(4);
  });

  it('records reviewSubmitted event with hasComment=false when no comment', () => {
    const r = makeReview({ comment: null });
    const events = r.pullEvents();
    const payload = events[0]?.payload as { hasComment: boolean };
    expect(payload.hasComment).toBe(false);
  });

  it('does NOT include comment text in the event payload', () => {
    const r = makeReview({ comment: ReviewComment.create('Secret text') });
    const events = r.pullEvents();
    const rawPayload = JSON.stringify(events[0]?.payload);
    expect(rawPayload).not.toContain('Secret text');
  });
});

describe('Review.canEdit', () => {
  it('returns true at exactly createdAt', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = makeReview({ now });
    expect(r.canEdit(now)).toBe(true);
  });

  it('returns true at createdAt + 24h - 1ms', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = makeReview({ now });
    const atWindow = new Date(now.getTime() + 24 * 60 * 60 * 1000 - 1);
    expect(r.canEdit(atWindow)).toBe(true);
  });

  it('returns false at createdAt + 24h (window boundary — exclusive)', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = makeReview({ now });
    const atBoundary = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    expect(r.canEdit(atBoundary)).toBe(false);
  });

  it('returns false at createdAt + 24h + 1ms', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = makeReview({ now });
    const afterWindow = new Date(now.getTime() + 24 * 60 * 60 * 1000 + 1);
    expect(r.canEdit(afterWindow)).toBe(false);
  });
});

describe('Review.edit', () => {
  it('updates rating and records reviewEdited', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = makeReview({ now });
    r.pullEvents(); // drain submit event

    const editTime = new Date(now.getTime() + 60 * 60 * 1000); // +1h
    r.edit({
      rating: Rating.create(5),
      comment: ReviewComment.create('Even better!'),
      now: editTime,
    });

    expect(r.rating.value).toBe(5);
    expect(r.comment?.value).toBe('Even better!');
    expect(r.updatedAt).toEqual(editTime);

    const events = r.pullEvents();
    expect(events).toHaveLength(1);
    expect(events[0]?.type).toBe('reviews.reviewEdited');
  });

  it('is a no-op when nothing changes', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = makeReview({ now, comment: ReviewComment.create('Same') });
    r.pullEvents();

    const editTime = new Date(now.getTime() + 60 * 60 * 1000);
    r.edit({ rating: Rating.create(4), comment: ReviewComment.create('Same'), now: editTime });

    expect(r.pullEvents()).toHaveLength(0);
    expect(r.updatedAt).toEqual(now); // unchanged
  });

  it('throws conflict with subcode reviews.editWindowExpired after 24h', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = makeReview({ now });
    const afterWindow = new Date(now.getTime() + 24 * 60 * 60 * 1000 + 1);

    let thrown: unknown;
    try {
      r.edit({ rating: Rating.create(3), comment: null, now: afterWindow });
    } catch (e) {
      thrown = e;
    }
    expect(thrown).toMatchObject({
      code: 'CONFLICT',
      details: { subcode: 'reviews.editWindowExpired' },
    });
  });

  it('does NOT include comment text in the reviewEdited event payload', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = makeReview({ now });
    r.pullEvents();

    const editTime = new Date(now.getTime() + 1000);
    r.edit({
      rating: Rating.create(5),
      comment: ReviewComment.create('Private thoughts'),
      now: editTime,
    });

    const events = r.pullEvents();
    expect(JSON.stringify(events[0]?.payload)).not.toContain('Private thoughts');
  });
});

describe('Review.hide', () => {
  it('hides the review and records reviewHidden', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = makeReview({ now });
    r.pullEvents();

    const hideTime = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000);
    r.hide({
      hiddenByUserId: 'mod_001',
      reportId: 'rpt_001',
      reason: 'Harassment',
      now: hideTime,
    });

    expect(r.hidden).toBe(true);
    expect(r.hiddenAt).toEqual(hideTime);
    expect(r.hiddenReason).toBe('Harassment');

    const events = r.pullEvents();
    expect(events).toHaveLength(1);
    expect(events[0]?.type).toBe('reviews.reviewHidden');
    const payload = events[0]?.payload as { hiddenByUserId: string; reportId: string };
    expect(payload.hiddenByUserId).toBe('mod_001');
    expect(payload.reportId).toBe('rpt_001');
  });

  it('is idempotent — second hide is a no-op', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = makeReview({ now });
    r.pullEvents();

    const hideTime = new Date(now.getTime() + 1000);
    r.hide({ hiddenByUserId: 'mod_001', reportId: 'rpt_001', reason: 'Spam', now: hideTime });
    r.pullEvents(); // drain first hide event

    r.hide({ hiddenByUserId: 'mod_002', reportId: 'rpt_002', reason: 'Harassment', now: hideTime });
    expect(r.pullEvents()).toHaveLength(0);
  });
});

describe('Review.rehydrate', () => {
  it('restores all fields without emitting events', () => {
    const now = new Date('2025-01-01T12:00:00Z');
    const r = Review.rehydrate({
      id: 'rev_999',
      eventId: 'evt_999',
      raterUserId: 'u1',
      ratedUserId: 'u2',
      rating: Rating.create(2),
      comment: ReviewComment.create('Meh'),
      createdAt: now,
      updatedAt: now,
      hidden: false,
      hiddenAt: null,
      hiddenReason: null,
    });
    expect(r.id).toBe('rev_999');
    expect(r.rating.value).toBe(2);
    expect(r.pullEvents()).toHaveLength(0);
  });
});
