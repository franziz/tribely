import type { DomainEvent } from '@/core/events/domain-event.js';

export const EVENT_COVER_PHOTO_REPLACED = 'events.eventCoverPhotoReplaced' as const;

/**
 * Emitted when a host replaces the cover photo on an existing Event.
 *
 * Minimal payload (single-attribute lifecycle event). This deliberately
 * diverges from the full-snapshot convention used by `events.eventUpdated` —
 * that convention exists because `eventUpdated` feeds discovery projections
 * that consume the entire post-state. This event has no projection consumer
 * in scope (TRI-306); a minimal payload avoids shipping projection-readiness
 * overhead for a currently unused consumer path. If a projection consumer is
 * added later, the payload can be expanded with a schema version bump.
 */
export interface EventCoverPhotoReplacedPayload {
  eventId: string;
  hostUserId: string;
  coverPhotoStorageKey: string;
  replacedAt: string;
}

export type EventCoverPhotoReplacedEvent = DomainEvent<EventCoverPhotoReplacedPayload> & {
  type: typeof EVENT_COVER_PHOTO_REPLACED;
};

export const eventCoverPhotoReplaced = (
  payload: EventCoverPhotoReplacedPayload,
): EventCoverPhotoReplacedEvent => ({
  type: EVENT_COVER_PHOTO_REPLACED,
  aggregateType: 'Event',
  aggregateId: payload.eventId,
  payload,
  version: 1,
});
