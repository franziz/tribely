import type { DomainEvent } from '@/core/events/domain-event.js';

export const JOIN_REQUEST_REJECTED = 'joinRequests.rejected' as const;

/**
 * Emitted when a host rejects a pending JoinRequest. Reason is free-form
 * host-supplied text (1-500 chars; trimmed). Consumers (notification feature)
 * surface this back to the requester. The reason is part of the audit trail —
 * it's why we don't allow a silent "ignore" path on the host side.
 */
export interface JoinRequestRejectedPayload {
  id: string;
  eventId: string;
  requesterUserId: string;
  rejectedByUserId: string;
  reason: string;
  rejectedAt: string;
}

export type JoinRequestRejectedEvent = DomainEvent<JoinRequestRejectedPayload> & {
  type: typeof JOIN_REQUEST_REJECTED;
};

export const joinRequestRejected = (
  payload: JoinRequestRejectedPayload,
): JoinRequestRejectedEvent => ({
  type: JOIN_REQUEST_REJECTED,
  aggregateType: 'JoinRequest',
  aggregateId: payload.id,
  payload,
  version: 1,
});
