import type { DomainEvent } from '@/core/events/domain-event.js';

export const EMAIL_VERIFICATION_ISSUED = 'auth.emailVerificationIssued' as const;

export interface EmailVerificationIssuedPayload {
  tokenId: string;
  userId: string;
  issuedAt: string;
  expiresAt: string;
}

export type EmailVerificationIssuedEvent = DomainEvent<EmailVerificationIssuedPayload> & {
  type: typeof EMAIL_VERIFICATION_ISSUED;
};

export const emailVerificationIssued = (
  payload: EmailVerificationIssuedPayload,
): EmailVerificationIssuedEvent => ({
  type: EMAIL_VERIFICATION_ISSUED,
  aggregateType: 'EmailVerificationToken',
  aggregateId: payload.tokenId,
  payload,
  version: 1,
});
