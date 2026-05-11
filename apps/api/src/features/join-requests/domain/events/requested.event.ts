import type { DomainEvent } from '@/core/events/domain-event.js';

export const JOIN_REQUEST_REQUESTED = 'joinRequests.requested' as const;

/**
 * Emitted when a user submits a request to join an event (status='pending').
 *
 * Carries a small snapshot of the parent event (`startsAt`, `endsAt`) so
 * downstream notification consumers don't need a follow-up lookup to compose
 * "your request to join '<title>' starting <when>" copy. Venue is NOT included
 * here — leak less for pending requests that may never be approved.
 *
 * Note: in the auto-approve path, the aggregate emits THIS event AND
 * `joinRequests.approved` together; subscribers should treat the pair as
 * causally ordered (the publisher writes both to the outbox in the same
 * transaction with monotonic `seq`).
 */
export interface JoinRequestRequestedPayload {
  id: string;
  eventId: string;
  requesterUserId: string;
  requestedAt: string;
  eventStartsAt: string;
  eventEndsAt: string;
}

export type JoinRequestRequestedEvent = DomainEvent<JoinRequestRequestedPayload> & {
  type: typeof JOIN_REQUEST_REQUESTED;
};

export const joinRequestRequested = (
  payload: JoinRequestRequestedPayload,
): JoinRequestRequestedEvent => ({
  type: JOIN_REQUEST_REQUESTED,
  aggregateType: 'JoinRequest',
  aggregateId: payload.id,
  payload,
  version: 1,
});
