import type { DomainEvent } from '@/core/events/domain-event.js';

export const PHONE_VERIFIED = 'auth.phoneVerified' as const;

export interface PhoneVerifiedPayload {
  userId: string;
  phoneE164: string;
  verifiedAt: string; // ISO-8601 UTC
}

export type PhoneVerifiedEvent = DomainEvent<PhoneVerifiedPayload> & {
  type: typeof PHONE_VERIFIED;
};

export const phoneVerified = (payload: PhoneVerifiedPayload): PhoneVerifiedEvent => ({
  type: PHONE_VERIFIED,
  aggregateType: 'User',
  aggregateId: payload.userId,
  payload,
  version: 1,
});
