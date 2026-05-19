import type { DomainEvent } from '@/core/events/domain-event.js';

export const CHECK_IN_ACKNOWLEDGED = 'checkIns.checkInAcknowledged' as const;

export interface CheckInAcknowledgedPayload {
  checkInId: string;
  userId: string;
  eventId: string;
  acknowledgedAt: string;
}

export type CheckInAcknowledgedEvent = DomainEvent<CheckInAcknowledgedPayload> & {
  type: typeof CHECK_IN_ACKNOWLEDGED;
};

export const checkInAcknowledged = (
  payload: CheckInAcknowledgedPayload,
): CheckInAcknowledgedEvent => ({
  type: CHECK_IN_ACKNOWLEDGED,
  aggregateType: 'PostEventCheckIn',
  aggregateId: payload.checkInId,
  payload,
  version: 1,
});
