import type { DomainEvent } from '@/core/events/domain-event.js';

export const JOIN_REQUEST_APPROVED = 'joinRequests.approved' as const;

/**
 * Emitted when a JoinRequest transitions to status='approved'. Carries a rich
 * snapshot (host, venue, time window) so post-approval features — chat thread
 * creation, "on my way" check-in, calendar invite — can react without an extra
 * lookup on the parent Event row. Avoids a schema migration when a new
 * post-approval consumer needs more context than just the IDs.
 */
export interface JoinRequestApprovedPayload {
  id: string;
  eventId: string;
  requesterUserId: string;
  approvedByUserId: string;
  approvedAt: string;
  hostUserId: string;
  eventStartsAt: string;
  eventEndsAt: string;
  eventVenue: {
    address: string;
    city: string;
    latitude: number;
    longitude: number;
  };
}

export type JoinRequestApprovedEvent = DomainEvent<JoinRequestApprovedPayload> & {
  type: typeof JOIN_REQUEST_APPROVED;
};

export const joinRequestApproved = (
  payload: JoinRequestApprovedPayload,
): JoinRequestApprovedEvent => ({
  type: JOIN_REQUEST_APPROVED,
  aggregateType: 'JoinRequest',
  aggregateId: payload.id,
  payload,
  version: 1,
});
