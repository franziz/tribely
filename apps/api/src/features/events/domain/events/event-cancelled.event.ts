import type { DomainEvent } from '@/core/events/domain-event.js';

export const EVENT_CANCELLED = 'events.eventCancelled' as const;

/**
 * Emitted when an Event transitions to status='cancelled'. Reason is free-form
 * (host-supplied, e.g. "weather", "venue closed"). Consumers (e.g. join-request
 * feature in TRI-20) typically react by notifying joiners.
 */
export interface EventCancelledPayload {
  eventId: string;
  hostUserId: string;
  reason: string;
  cancelledAt: string;
}

export type EventCancelledEvent = DomainEvent<EventCancelledPayload> & {
  type: typeof EVENT_CANCELLED;
};

export const eventCancelled = (payload: EventCancelledPayload): EventCancelledEvent => ({
  type: EVENT_CANCELLED,
  aggregateType: 'Event',
  aggregateId: payload.eventId,
  payload,
  version: 1,
});
