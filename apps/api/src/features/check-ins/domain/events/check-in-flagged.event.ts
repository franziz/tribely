import type { DomainEvent } from '@/core/events/domain-event.js';

export const CHECK_IN_FLAGGED = 'checkIns.checkInFlagged' as const;

export interface CheckInFlaggedPayload {
  checkInId: string;
  userId: string;
  eventId: string;
  hostUserId: string;
  flaggedAt: string;
  reportBody: string;
  disclaimerAcknowledged: boolean;
}

export type CheckInFlaggedEvent = DomainEvent<CheckInFlaggedPayload> & {
  type: typeof CHECK_IN_FLAGGED;
};

export const checkInFlagged = (payload: CheckInFlaggedPayload): CheckInFlaggedEvent => ({
  type: CHECK_IN_FLAGGED,
  aggregateType: 'PostEventCheckIn',
  aggregateId: payload.checkInId,
  payload,
  version: 1,
});
