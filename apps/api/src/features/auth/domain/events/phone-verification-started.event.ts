import type { DomainEvent } from '@/core/events/domain-event.js';

export const PHONE_VERIFICATION_STARTED = 'auth.phoneVerificationStarted' as const;

export interface PhoneVerificationStartedPayload {
  userId: string;
  phoneE164: string;
  startedAt: string; // ISO-8601 UTC
}

export type PhoneVerificationStartedEvent = DomainEvent<PhoneVerificationStartedPayload> & {
  type: typeof PHONE_VERIFICATION_STARTED;
};

/**
 * Synthetic-aggregate event — no PhoneVerification aggregate exists.
 * The use case (SWE-5) publishes this directly via EventPublisher.publish(ctx, ...)
 * with a createId() as the synthetic aggregateId. The User aggregate is uninvolved.
 */
export const phoneVerificationStarted = (
  payload: PhoneVerificationStartedPayload,
  syntheticId: string,
): PhoneVerificationStartedEvent => ({
  type: PHONE_VERIFICATION_STARTED,
  aggregateType: 'PhoneVerification',
  aggregateId: syntheticId,
  payload,
  version: 1,
});
