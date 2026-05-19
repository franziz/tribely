import type { DomainEvent } from '@/core/events/domain-event.js';

export const JOIN_REQUEST_CANCELLED_BY_SYSTEM = 'joinRequests.cancelledBySystem' as const;

/**
 * Emitted when the system cancels a join request on behalf of no actor —
 * currently triggered by a user block (one of the pair blocks the other).
 *
 * `reason` is a closed enum at launch:
 *   - `'blocked'` — cancelled because a block was placed between the two users.
 *
 * Per CEO Condition 3: unblocking does NOT restore these cancelled requests.
 * Consumers must not reverse this cancellation on `userUnblocked`.
 */
export interface JoinRequestCancelledBySystemPayload {
  joinRequestId: string;
  eventId: string;
  requesterUserId: string;
  hostUserId: string;
  reason: 'blocked';
  occurredAt: string;
}

export type JoinRequestCancelledBySystemEvent = DomainEvent<JoinRequestCancelledBySystemPayload> & {
  type: typeof JOIN_REQUEST_CANCELLED_BY_SYSTEM;
};

export const joinRequestCancelledBySystem = (
  payload: JoinRequestCancelledBySystemPayload,
): JoinRequestCancelledBySystemEvent => ({
  type: JOIN_REQUEST_CANCELLED_BY_SYSTEM,
  aggregateType: 'JoinRequest',
  aggregateId: payload.joinRequestId,
  payload,
  version: 1,
});
