import type { DomainEvent } from '@/core/events/domain-event.js';

export const JOIN_REQUEST_REMOVED_BY_HOST = 'joinRequests.removedByHost' as const;

/**
 * Emitted when a host removes an approved attendee from the event. Reason is
 * required (1-200 chars; trimmed). `removedByUserId` equals `hostUserId` in
 * Path B (host removes directly), but both fields are emitted for symmetry
 * with `joinRequestApproved` and to keep Path C optionality open for admins.
 */
export interface JoinRequestRemovedByHostPayload {
  id: string;
  eventId: string;
  requesterUserId: string;
  removedByUserId: string;
  hostUserId: string;
  reason: string;
  removedAt: string;
}

export type JoinRequestRemovedByHostEvent = DomainEvent<JoinRequestRemovedByHostPayload> & {
  type: typeof JOIN_REQUEST_REMOVED_BY_HOST;
};

export const joinRequestRemovedByHost = (
  payload: JoinRequestRemovedByHostPayload,
): JoinRequestRemovedByHostEvent => ({
  type: JOIN_REQUEST_REMOVED_BY_HOST,
  aggregateType: 'JoinRequest',
  aggregateId: payload.id,
  payload,
  version: 1,
});
