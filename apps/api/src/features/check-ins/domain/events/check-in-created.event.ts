import type { DomainEvent } from '@/core/events/domain-event.js';

export const CHECK_IN_CREATED = 'checkIns.checkInCreated' as const;

export interface CheckInCreatedPayload {
  checkInId: string;
  userId: string;
  eventId: string;
  hostUserId: string;
  createdAt: string;
}

export type CheckInCreatedEvent = DomainEvent<CheckInCreatedPayload> & {
  type: typeof CHECK_IN_CREATED;
};

export const checkInCreated = (payload: CheckInCreatedPayload): CheckInCreatedEvent => ({
  type: CHECK_IN_CREATED,
  aggregateType: 'PostEventCheckIn',
  aggregateId: payload.checkInId,
  payload,
  version: 1,
});
