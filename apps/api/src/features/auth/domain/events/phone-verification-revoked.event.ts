import type { DomainEvent } from '@/core/events/domain-event.js';

export const PHONE_VERIFICATION_REVOKED = 'auth.phoneVerificationRevoked' as const;

export interface PhoneVerificationRevokedPayload {
  oldUserId: string;
  newUserId: string;
  /** SHA-256 hash of the E.164 phone number — never plaintext. Hashed at the use-case layer. */
  phoneE164Hash: string;
  revokedAt: string; // ISO-8601 UTC
}

export type PhoneVerificationRevokedEvent = DomainEvent<PhoneVerificationRevokedPayload> & {
  type: typeof PHONE_VERIFICATION_REVOKED;
};

export const phoneVerificationRevoked = (
  payload: PhoneVerificationRevokedPayload,
): PhoneVerificationRevokedEvent => ({
  type: PHONE_VERIFICATION_REVOKED,
  aggregateType: 'User',
  aggregateId: payload.oldUserId,
  payload,
  version: 1,
});
