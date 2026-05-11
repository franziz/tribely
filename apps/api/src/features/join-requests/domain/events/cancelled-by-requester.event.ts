import type { DomainEvent } from '@/core/events/domain-event.js';

export const JOIN_REQUEST_CANCELLED_BY_REQUESTER = 'joinRequests.cancelledByRequester' as const;

/**
 * Emitted when the requester cancels their own join request. Allowed from BOTH
 * `pending` AND `approved` — `previousStatus` lets consumers distinguish the
 * two paths (notifying the host of an approved-then-cancelled drop-out is a
 * different message than retracting a pending request).
 *
 * Host-initiated removal of an approved attendee is a separate flow (and a
 * separate future event) — `host.removedAttendee` — not this one.
 */
export interface JoinRequestCancelledByRequesterPayload {
  id: string;
  eventId: string;
  requesterUserId: string;
  previousStatus: 'pending' | 'approved';
  cancelledAt: string;
}

export type JoinRequestCancelledByRequesterEvent =
  DomainEvent<JoinRequestCancelledByRequesterPayload> & {
    type: typeof JOIN_REQUEST_CANCELLED_BY_REQUESTER;
  };

export const joinRequestCancelledByRequester = (
  payload: JoinRequestCancelledByRequesterPayload,
): JoinRequestCancelledByRequesterEvent => ({
  type: JOIN_REQUEST_CANCELLED_BY_REQUESTER,
  aggregateType: 'JoinRequest',
  aggregateId: payload.id,
  payload,
  version: 1,
});
