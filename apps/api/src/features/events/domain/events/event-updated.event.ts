import type { DomainEvent } from '@/core/events/domain-event.js';
import type { EventCategoryValue } from '../value-objects/event-category.js';
import type { VenueCategoryValue } from '../value-objects/venue-category.js';

export const EVENT_UPDATED = 'events.eventUpdated' as const;

/**
 * Emitted when a host edits an existing Event (allowed in `draft` or
 * `published` status; rejected otherwise — see `Event.edit`).
 *
 * Like `events.eventCreated`, the payload is a full post-edit snapshot so
 * projections (search index, mobile cached feed) can update their read model
 * without re-fetching. Lean diff-style payloads would force consumers to
 * track previous state — strictly more complex for no real benefit.
 */
export interface EventUpdatedPayload {
  eventId: string;
  hostUserId: string;
  title: string;
  description: string | null;
  venue: { address: string; city: string; latitude: number; longitude: number };
  startsAt: string;
  endsAt: string;
  capacity: number;
  category: EventCategoryValue;
  venueCategory: VenueCategoryValue;
  costSplit: 'own' | 'host_paid' | 'split';
  approvalMode: 'auto' | 'manual';
  updatedAt: string;
}

export type EventUpdatedEvent = DomainEvent<EventUpdatedPayload> & {
  type: typeof EVENT_UPDATED;
};

export const eventUpdated = (payload: EventUpdatedPayload): EventUpdatedEvent => ({
  type: EVENT_UPDATED,
  aggregateType: 'Event',
  aggregateId: payload.eventId,
  payload,
  version: 1,
});
