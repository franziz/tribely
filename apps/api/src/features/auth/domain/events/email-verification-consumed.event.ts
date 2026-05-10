import type { DomainEvent } from '@/core/events/domain-event.js';

export const EMAIL_VERIFICATION_CONSUMED = 'auth.emailVerificationConsumed' as const;

export interface EmailVerificationConsumedPayload {
  tokenId: string;
  userId: string;
  consumedAt: string;
}

export type EmailVerificationConsumedEvent = DomainEvent<EmailVerificationConsumedPayload> & {
  type: typeof EMAIL_VERIFICATION_CONSUMED;
};

export const emailVerificationConsumed = (
  payload: EmailVerificationConsumedPayload,
): EmailVerificationConsumedEvent => ({
  type: EMAIL_VERIFICATION_CONSUMED,
  aggregateType: 'EmailVerificationToken',
  aggregateId: payload.tokenId,
  payload,
  version: 1,
});
