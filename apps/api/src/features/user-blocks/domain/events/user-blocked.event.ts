import type { DomainEvent } from '@/core/events/domain-event.js';

export const USER_BLOCKED = 'user-blocks.userBlocked' as const;

/**
 * Emitted when a user blocks another user.
 *
 * Carries initiatorUserId + blockedUserId so downstream consumers (e.g.,
 * join-request cascade) can take action without a follow-up lookup.
 */
export interface UserBlockedPayload {
  id: string;
  initiatorUserId: string;
  blockedUserId: string;
  createdAt: string;
}

export type UserBlockedEvent = DomainEvent<UserBlockedPayload> & {
  type: typeof USER_BLOCKED;
};

export const userBlocked = (payload: UserBlockedPayload): UserBlockedEvent => ({
  type: USER_BLOCKED,
  aggregateType: 'UserBlock',
  aggregateId: payload.id,
  payload,
  version: 1,
});
