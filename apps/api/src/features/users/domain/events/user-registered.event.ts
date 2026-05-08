import type { DomainEvent } from '@/core/events/domain-event.js';

export const USER_REGISTERED = 'users.userRegistered' as const;

export interface UserRegisteredPayload {
  userId: string;
  email: string;
  displayName: string;
  registeredAt: string;
}

export type UserRegisteredEvent = DomainEvent<UserRegisteredPayload> & {
  type: typeof USER_REGISTERED;
};

export const userRegistered = (payload: UserRegisteredPayload): UserRegisteredEvent => ({
  type: USER_REGISTERED,
  aggregateType: 'User',
  aggregateId: payload.userId,
  payload,
  version: 1,
});
