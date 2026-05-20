import type { Review } from '../../domain/entities/review.js';

/** 14 days in milliseconds — after this window, all reviews become visible. */
const BLIND_WINDOW_MS = 14 * 24 * 60 * 60 * 1000;

export type ReviewVisibility = 'visible' | 'blind-mutual-pending' | 'hidden';

/**
 * Pure function: derives the visibility of a single review row for a given
 * viewer.
 *
 * Rules (evaluated in order):
 *  1. `hidden` → always `'hidden'` (moderator decision is final).
 *  2. `viewerId === review.raterUserId` → `'visible'` (author always sees own).
 *  3. `counterpartExists` → `'visible'` (both parties have reviewed; unblind).
 *  4. `now - eventCompletedAt >= 14 days` → `'visible'` (window expired; unblind).
 *  5. Otherwise → `'blind-mutual-pending'`.
 *
 * Callers (list-reviews-for-user use case) use this to:
 *  - For `'hidden'` rows: exclude from response unless viewer === author.
 *  - For `'blind-mutual-pending'` rows: return `{ rating: null, comment: null,
 *    hiddenForMutualWindow: true }` so the mobile can render the pending copy.
 *  - For `'visible'` rows: return full content.
 */
export const reviewVisibilityProjection = (input: {
  review: Review;
  viewerId: string;
  counterpartExists: boolean;
  eventCompletedAt: Date;
  now: Date;
}): ReviewVisibility => {
  const { review, viewerId, counterpartExists, eventCompletedAt, now } = input;

  if (review.hidden) {
    return 'hidden';
  }

  if (viewerId === review.raterUserId) {
    return 'visible';
  }

  if (counterpartExists) {
    return 'visible';
  }

  if (now.getTime() - eventCompletedAt.getTime() >= BLIND_WINDOW_MS) {
    return 'visible';
  }

  return 'blind-mutual-pending';
};
