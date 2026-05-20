import type { DomainEvent } from '@/core/events/domain-event.js';

export const REVIEW_HIDDEN = 'reviews.reviewHidden' as const;

/**
 * Emitted when a Review is hidden by a moderator following a report.
 *
 * `reportId` links back to the moderation report that triggered the hide.
 * `reason` is a moderator-supplied free-text explanation (not exposed to
 * the review author — only surfaced in the admin audit trail).
 *
 * PDPA / audit-leak: comment text is NEVER included in event payloads.
 */
export interface ReviewHiddenPayload {
  reviewId: string;
  eventId: string;
  raterUserId: string;
  ratedUserId: string;
  hiddenByUserId: string;
  reportId: string;
  reason: string;
  hiddenAt: string;
}

export type ReviewHiddenEvent = DomainEvent<ReviewHiddenPayload> & {
  type: typeof REVIEW_HIDDEN;
};

export const reviewHidden = (payload: ReviewHiddenPayload): ReviewHiddenEvent => ({
  type: REVIEW_HIDDEN,
  aggregateType: 'Review',
  aggregateId: payload.reviewId,
  payload,
  version: 1,
});
