import type { DomainEvent } from '@/core/events/domain-event.js';

export const USER_UNBLOCKED = 'user-blocks.userUnblocked' as const;

/**
 * Emitted when a user unblocks a previously blocked user.
 *
 * Per CEO Condition 3: unblocking does NOT restore cancelled join requests.
 * Consumers must NOT reverse any cancellations triggered by the prior block.
 */
export interface UserUnblockedPayload {
  id: string;
  initiatorUserId: string;
  blockedUserId: string;
  unblockedAt: string;
}

export type UserUnblockedEvent = DomainEvent<UserUnblockedPayload> & {
  type: typeof USER_UNBLOCKED;
};

export const userUnblocked = (payload: UserUnblockedPayload): UserUnblockedEvent => ({
  type: USER_UNBLOCKED,
  aggregateType: 'UserBlock',
  aggregateId: payload.id,
  payload,
  version: 1,
});
