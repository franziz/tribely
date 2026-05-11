import type { DomainEvent } from '@/core/events/domain-event.js';

export const EVENT_PUBLISHED = 'events.eventPublished' as const;

/**
 * Emitted when a draft Event transitions to status='published' and becomes
 * visible to potential joiners.
 */
export interface EventPublishedPayload {
  eventId: string;
  hostUserId: string;
  publishedAt: string;
}

export type EventPublishedEvent = DomainEvent<EventPublishedPayload> & {
  type: typeof EVENT_PUBLISHED;
};

export const eventPublished = (payload: EventPublishedPayload): EventPublishedEvent => ({
  type: EVENT_PUBLISHED,
  aggregateType: 'Event',
  aggregateId: payload.eventId,
  payload,
  version: 1,
});
