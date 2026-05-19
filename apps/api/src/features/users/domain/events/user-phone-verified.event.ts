import type { DomainEvent } from '@/core/events/domain-event.js';

export const USER_PHONE_VERIFIED = 'users.userPhoneVerified' as const;

export interface UserPhoneVerifiedPayload {
  userId: string;
  phoneE164: string;
  verifiedAt: string; // ISO-8601 UTC
}

export type UserPhoneVerifiedEvent = DomainEvent<UserPhoneVerifiedPayload> & {
  type: typeof USER_PHONE_VERIFIED;
};

export const userPhoneVerified = (payload: UserPhoneVerifiedPayload): UserPhoneVerifiedEvent => ({
  type: USER_PHONE_VERIFIED,
  aggregateType: 'User',
  aggregateId: payload.userId,
  payload,
  version: 1,
});
