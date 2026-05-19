import type { DomainEvent } from '@/core/events/domain-event.js';

export const REVIEW_EDITED = 'reviews.reviewEdited' as const;

/**
 * Emitted when a Review's rating or comment is edited within the 24h window.
 *
 * PDPA / audit-leak: comment text is NEVER included in event payloads.
 * `hasComment` is the only signal about comment presence.
 */
export interface ReviewEditedPayload {
  reviewId: string;
  eventId: string;
  raterUserId: string;
  ratedUserId: string;
  rating: number;
  hasComment: boolean;
  editedAt: string;
}

export type ReviewEditedEvent = DomainEvent<ReviewEditedPayload> & {
  type: typeof REVIEW_EDITED;
};

export const reviewEdited = (payload: ReviewEditedPayload): ReviewEditedEvent => ({
  type: REVIEW_EDITED,
  aggregateType: 'Review',
  aggregateId: payload.reviewId,
  payload,
  version: 1,
});
