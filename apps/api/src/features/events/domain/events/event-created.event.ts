import type { DomainEvent } from '@/core/events/domain-event.js';
import type { EventCategoryValue } from '../value-objects/event-category.js';

export const EVENT_CREATED = 'events.eventCreated' as const;

/**
 * Emitted when an Event aggregate is first created (status='draft').
 *
 * Carries a rich snapshot — downstream projections / search indexers can
 * build their read model without an extra lookup. Subsequent state-change
 * events (`events.eventPublished`, `events.eventCancelled`, etc.) are lean
 * by comparison; consumers that need the latest state fetch on demand.
 */
export interface EventCreatedPayload {
  eventId: string;
  hostUserId: string;
  title: string;
  description: string | null;
  venue: { address: string; latitude: number; longitude: number };
  startsAt: string;
  endsAt: string;
  capacity: number;
  category: EventCategoryValue;
  costSplit: 'own' | 'host_paid' | 'split';
  approvalMode: 'auto' | 'manual';
  createdAt: string;
}

export type EventCreatedEvent = DomainEvent<EventCreatedPayload> & {
  type: typeof EVENT_CREATED;
};

export const eventCreated = (payload: EventCreatedPayload): EventCreatedEvent => ({
  type: EVENT_CREATED,
  aggregateType: 'Event',
  aggregateId: payload.eventId,
  payload,
  version: 1,
});
