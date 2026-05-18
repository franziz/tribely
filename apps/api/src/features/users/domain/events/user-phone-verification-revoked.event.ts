import type { DomainEvent } from '@/core/events/domain-event.js';

export const USER_PHONE_VERIFICATION_REVOKED = 'users.userPhoneVerificationRevoked' as const;

export interface UserPhoneVerificationRevokedPayload {
  oldUserId: string;
  newUserId: string;
  /** SHA-256 hash of the E.164 phone number — never plaintext. Hashed at the use-case layer. */
  phoneE164Hash: string;
  revokedAt: string; // ISO-8601 UTC
}

export type UserPhoneVerificationRevokedEvent = DomainEvent<UserPhoneVerificationRevokedPayload> & {
  type: typeof USER_PHONE_VERIFICATION_REVOKED;
};

export const userPhoneVerificationRevoked = (
  payload: UserPhoneVerificationRevokedPayload,
): UserPhoneVerificationRevokedEvent => ({
  type: USER_PHONE_VERIFICATION_REVOKED,
  aggregateType: 'User',
  aggregateId: payload.oldUserId,
  payload,
  version: 1,
});
