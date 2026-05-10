import type { DomainEvent } from '@/core/events/domain-event.js';

export const USER_EMAIL_VERIFIED = 'users.userEmailVerified' as const;

export interface UserEmailVerifiedPayload {
  userId: string;
  email: string;
  verifiedAt: string;
}

export type UserEmailVerifiedEvent = DomainEvent<UserEmailVerifiedPayload> & {
  type: typeof USER_EMAIL_VERIFIED;
};

export const userEmailVerified = (payload: UserEmailVerifiedPayload): UserEmailVerifiedEvent => ({
  type: USER_EMAIL_VERIFIED,
  aggregateType: 'User',
  aggregateId: payload.userId,
  payload,
  version: 1,
});
