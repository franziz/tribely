import type { DomainEvent } from '@/core/events/domain-event.js';

export const SAFETY_REMINDER_RESET = 'users.safetyReminderReset' as const;

export interface SafetyReminderResetPayload {
  userId: string;
  resetReason: string;
  resetAt: string;
}

export type SafetyReminderResetEvent = DomainEvent<SafetyReminderResetPayload> & {
  type: typeof SAFETY_REMINDER_RESET;
};

export const safetyReminderReset = (
  payload: SafetyReminderResetPayload,
): SafetyReminderResetEvent => ({
  type: SAFETY_REMINDER_RESET,
  aggregateType: 'User',
  aggregateId: payload.userId,
  payload,
  version: 1,
});
