import type { DomainEvent } from '@/core/events/domain-event.js';

export const PASSWORD_RESET = 'auth.passwordReset' as const;

export interface PasswordResetPayload {
  userId: string;
  resetAt: string;
}

export type PasswordResetEvent = DomainEvent<PasswordResetPayload> & {
  type: typeof PASSWORD_RESET;
};

export const passwordReset = (payload: PasswordResetPayload): PasswordResetEvent => ({
  type: PASSWORD_RESET,
  aggregateType: 'Credential',
  aggregateId: payload.userId,
  payload,
  version: 1,
});
