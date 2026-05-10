import type { DomainEvent } from '@/core/events/domain-event.js';

export type EmailVerificationInvalidatedReason =
  | 'too_many_attempts'
  | 'replaced'
  | 'already_verified';

export const EMAIL_VERIFICATION_INVALIDATED = 'auth.emailVerificationInvalidated' as const;

export interface EmailVerificationInvalidatedPayload {
  tokenId: string;
  userId: string;
  reason: EmailVerificationInvalidatedReason;
  invalidatedAt: string;
}

export type EmailVerificationInvalidatedEvent = DomainEvent<EmailVerificationInvalidatedPayload> & {
  type: typeof EMAIL_VERIFICATION_INVALIDATED;
};

export const emailVerificationInvalidated = (
  payload: EmailVerificationInvalidatedPayload,
): EmailVerificationInvalidatedEvent => ({
  type: EMAIL_VERIFICATION_INVALIDATED,
  aggregateType: 'EmailVerificationToken',
  aggregateId: payload.tokenId,
  payload,
  version: 1,
});
