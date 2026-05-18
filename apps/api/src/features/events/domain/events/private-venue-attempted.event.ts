import type { DomainEvent } from '@/core/events/domain-event.js';
import type { VenueCategoryValue } from '../value-objects/venue-category.js';

export const PRIVATE_VENUE_ATTEMPTED = 'events.privateVenueAttempted' as const;

/**
 * Emitted when a host attempts to create or update an event with a venue that
 * fails the public-venue policy (either by category or keyword match).
 *
 * This is a synthetic-aggregate event — no `Event` aggregate is created.
 * The use case generates a fresh `aggregateId` via `createId()` at publish time,
 * and `aggregateType` is the sentinel `'PolicyRejection'` to signal that this
 * event does not correspond to a persisted aggregate row.
 *
 * Producer-only for v1. No consumer or subscriber is registered.
 */
export interface PrivateVenueAttemptedPayload {
  userId: string;
  /** The address/label the host typed. */
  attemptedVenueName: string;
  attemptedVenueCategory: VenueCategoryValue;
  reason: 'category_not_public' | 'keyword_match';
  /** Only set when reason='keyword_match'. */
  matchedKeyword: string | null;
  /** ISO timestamp of the rejection. */
  attemptedAt: string;
}

export type PrivateVenueAttemptedEvent = DomainEvent<PrivateVenueAttemptedPayload> & {
  type: typeof PRIVATE_VENUE_ATTEMPTED;
};

/**
 * Factory for the `events.privateVenueAttempted` domain event.
 *
 * Unlike standard aggregate events, the caller supplies `aggregateId` explicitly
 * (generated via `createId()` in the use case) because no `Event` aggregate
 * exists at rejection time.
 */
export const privateVenueAttempted = (
  payload: PrivateVenueAttemptedPayload,
  aggregateId: string,
): PrivateVenueAttemptedEvent => ({
  type: PRIVATE_VENUE_ATTEMPTED,
  aggregateType: 'PolicyRejection',
  aggregateId,
  payload,
  version: 1,
});
