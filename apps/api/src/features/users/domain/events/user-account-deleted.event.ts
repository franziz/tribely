import type { DomainEvent } from '@/core/events/domain-event.js';

export const USER_ACCOUNT_DELETED = 'users.userAccountDeleted' as const;

export interface UserAccountDeletedPayload {
  userId: string;
  deletedAt: string; // ISO-8601; Date serialized for event bus transport
}

export type UserAccountDeletedEvent = DomainEvent<UserAccountDeletedPayload> & {
  type: typeof USER_ACCOUNT_DELETED;
};

export const userAccountDeleted = (
  payload: UserAccountDeletedPayload,
): UserAccountDeletedEvent => ({
  type: USER_ACCOUNT_DELETED,
  aggregateType: 'User',
  aggregateId: payload.userId,
  payload,
  version: 1,
});
