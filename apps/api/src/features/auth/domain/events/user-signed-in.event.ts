import type { DomainEvent } from '@/core/events/domain-event.js';

export const USER_SIGNED_IN = 'auth.userSignedIn' as const;

export interface UserSignedInPayload {
  userId: string;
  signedInAt: string;
}

export type UserSignedInEvent = DomainEvent<UserSignedInPayload> & {
  type: typeof USER_SIGNED_IN;
};

export const userSignedIn = (payload: UserSignedInPayload): UserSignedInEvent => ({
  type: USER_SIGNED_IN,
  aggregateType: 'Credential',
  aggregateId: payload.userId,
  payload,
  version: 1,
});
