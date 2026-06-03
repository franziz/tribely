import type { DomainEvent } from '@/core/events/domain-event.js';

export const SAFETY_REMINDER_SHOWN = 'users.safetyReminderShown' as const;

export interface SafetyReminderShownPayload {
  userId: string;
  eventId: string;
  shownAt: string;
}

export type SafetyReminderShownEvent = DomainEvent<SafetyReminderShownPayload> & {
  type: typeof SAFETY_REMINDER_SHOWN;
};

export const safetyReminderShown = (
  payload: SafetyReminderShownPayload,
): SafetyReminderShownEvent => ({
  type: SAFETY_REMINDER_SHOWN,
  aggregateType: 'User',
  aggregateId: payload.userId,
  payload,
  version: 1,
});
