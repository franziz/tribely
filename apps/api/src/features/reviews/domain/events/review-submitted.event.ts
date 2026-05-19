import type { DomainEvent } from '@/core/events/domain-event.js';

export const REVIEW_SUBMITTED = 'reviews.reviewSubmitted' as const;

/**
 * Emitted when a Review is first submitted.
 *
 * PDPA / audit-leak: comment text is NEVER included in event payloads.
 * `hasComment` is the only signal about comment presence — actual text
 * is only readable from the reviews table under access-control.
 */
export interface ReviewSubmittedPayload {
  reviewId: string;
  eventId: string;
  raterUserId: string;
  ratedUserId: string;
  rating: number;
  hasComment: boolean;
  createdAt: string;
}

export type ReviewSubmittedEvent = DomainEvent<ReviewSubmittedPayload> & {
  type: typeof REVIEW_SUBMITTED;
};

export const reviewSubmitted = (payload: ReviewSubmittedPayload): ReviewSubmittedEvent => ({
  type: REVIEW_SUBMITTED,
  aggregateType: 'Review',
  aggregateId: payload.reviewId,
  payload,
  version: 1,
});
