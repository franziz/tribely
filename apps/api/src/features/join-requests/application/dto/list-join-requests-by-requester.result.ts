import type { JoinRequest } from '../../domain/entities/join-request.js';
import type { Event } from '@/features/events/domain/entities/event.js';

/**
 * Result of {@link ListJoinRequestsByRequesterUseCase.execute}.
 *
 * Each item pairs the join request row with a lightweight event summary so
 * the mobile list-view can render title + time + venue without a second fetch.
 * The cursor is a `(requestedAt, id)` keyset encoded by the use case; the
 * presentation layer encodes it as base64 on the wire.
 */
export interface JoinRequestWithEventSummary {
  joinRequest: JoinRequest;
  event: Pick<Event, 'id' | 'title' | 'startsAt' | 'endsAt' | 'status' | 'capacity'> & {
    venue: { address: string; city: string };
  };
}

export interface ListJoinRequestsByRequesterCursor {
  lastRequestedAt: Date;
  lastJoinRequestId: string;
}

export interface ListJoinRequestsByRequesterResult {
  items: JoinRequestWithEventSummary[];
  nextCursor: ListJoinRequestsByRequesterCursor | null;
}
