import type { DomainEvent } from '@/core/events/domain-event.js';

export const PASSWORD_RESET_REQUESTED = 'auth.passwordResetRequested' as const;

export interface PasswordResetRequestedPayload {
  tokenId: string;
  userId: string;
  issuedAt: string;
  expiresAt: string;
}

export type PasswordResetRequestedEvent = DomainEvent<PasswordResetRequestedPayload> & {
  type: typeof PASSWORD_RESET_REQUESTED;
};

export const passwordResetRequested = (
  payload: PasswordResetRequestedPayload,
): PasswordResetRequestedEvent => ({
  type: PASSWORD_RESET_REQUESTED,
  aggregateType: 'PasswordResetToken',
  aggregateId: payload.tokenId,
  payload,
  version: 1,
});
