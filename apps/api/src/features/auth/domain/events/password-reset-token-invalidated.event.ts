import type { DomainEvent } from '@/core/events/domain-event.js';

export type PasswordResetTokenInvalidatedReason = 'too_many_attempts' | 'replaced';

export const PASSWORD_RESET_TOKEN_INVALIDATED = 'auth.passwordResetTokenInvalidated' as const;

export interface PasswordResetTokenInvalidatedPayload {
  tokenId: string;
  userId: string;
  reason: PasswordResetTokenInvalidatedReason;
  invalidatedAt: string;
}

export type PasswordResetTokenInvalidatedEvent =
  DomainEvent<PasswordResetTokenInvalidatedPayload> & {
    type: typeof PASSWORD_RESET_TOKEN_INVALIDATED;
  };

export const passwordResetTokenInvalidated = (
  payload: PasswordResetTokenInvalidatedPayload,
): PasswordResetTokenInvalidatedEvent => ({
  type: PASSWORD_RESET_TOKEN_INVALIDATED,
  aggregateType: 'PasswordResetToken',
  aggregateId: payload.tokenId,
  payload,
  version: 1,
});
