import type { DomainEvent } from '@/core/events/domain-event.js';

export const EVENT_COMPLETED = 'events.eventCompleted' as const;

/**
 * Emitted when a published Event is marked completed (event happened, host
 * confirms). Downstream features (ratings, post-event surveys) hang off this.
 */
export interface EventCompletedPayload {
  eventId: string;
  hostUserId: string;
  completedAt: string;
}

export type EventCompletedEvent = DomainEvent<EventCompletedPayload> & {
  type: typeof EVENT_COMPLETED;
};

export const eventCompleted = (payload: EventCompletedPayload): EventCompletedEvent => ({
  type: EVENT_COMPLETED,
  aggregateType: 'Event',
  aggregateId: payload.eventId,
  payload,
  version: 1,
});
