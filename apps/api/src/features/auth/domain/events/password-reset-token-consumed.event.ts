import type { DomainEvent } from '@/core/events/domain-event.js';

export const PASSWORD_RESET_TOKEN_CONSUMED = 'auth.passwordResetTokenConsumed' as const;

export interface PasswordResetTokenConsumedPayload {
  tokenId: string;
  userId: string;
  consumedAt: string;
}

export type PasswordResetTokenConsumedEvent = DomainEvent<PasswordResetTokenConsumedPayload> & {
  type: typeof PASSWORD_RESET_TOKEN_CONSUMED;
};

export const passwordResetTokenConsumed = (
  payload: PasswordResetTokenConsumedPayload,
): PasswordResetTokenConsumedEvent => ({
  type: PASSWORD_RESET_TOKEN_CONSUMED,
  aggregateType: 'PasswordResetToken',
  aggregateId: payload.tokenId,
  payload,
  version: 1,
});
