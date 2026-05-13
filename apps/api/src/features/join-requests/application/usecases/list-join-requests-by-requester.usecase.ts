import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { ListJoinRequestsByRequesterResult } from '../dto/list-join-requests-by-requester.result.js';
import type {
  JoinRequestRepository,
  JoinRequestWithEventSummary,
  ListJoinRequestsByRequesterCursor,
} from '../../domain/repositories/join-request.repository.js';

export interface ListJoinRequestsByRequesterInput {
  requesterUserId: string;
  /** Optional: scopes the listing to a single event (event-detail screen). */
  eventId?: string;
  cursor?: ListJoinRequestsByRequesterCursor;
  limit: number;
}

const MAX_LIMIT = 50;

/**
 * Returns the authenticated user's own join requests ordered newest-first,
 * each enriched with an event summary so the mobile list-view can render
 * title / time / venue without a second fetch.
 *
 * Optional `eventId` filter: scopes to one event. The mobile event-detail
 * screen uses this to check whether the viewer already has a join request
 * for that event (so it can show "View your request" instead of "Join").
 *
 * Read-only query — no UnitOfWork, no events emitted.
 */
export class ListJoinRequestsByRequesterUseCase {
  constructor(
    private readonly joinRequests: JoinRequestRepository,
    private readonly events: EventRepository,
  ) {}

  async execute(
    input: ListJoinRequestsByRequesterInput,
  ): Promise<ListJoinRequestsByRequesterResult> {
    const limit = Math.min(input.limit, MAX_LIMIT);

    const page = await this.joinRequests.listByRequester(
      input.requesterUserId,
      input.eventId,
      input.cursor ?? null,
      limit,
    );

    // Collect the distinct event ids needed for this page and batch-fetch them
    // in a single repository call so we don't N+1 on the events table.
    const eventIds = [...new Set(page.joinRequests.map((jr) => jr.eventId))];

    // Fetch each event. Events that are somehow missing (deleted outside normal
    // flow) are filtered out rather than surfacing a 404 — the requester's own
    // request list should stay queryable even if a host deleted an event
    // through a future admin path.
    const eventMap = new Map<string, Awaited<ReturnType<EventRepository['findById']>>>();
    await Promise.all(
      eventIds.map(async (id) => {
        const event = await this.events.findById(id);
        eventMap.set(id, event);
      }),
    );

    const items: JoinRequestWithEventSummary[] = [];
    for (const jr of page.joinRequests) {
      const event = eventMap.get(jr.eventId);
      if (!event) continue; // skip orphaned rows; don't throw
      items.push({
        joinRequest: jr,
        event: {
          id: event.id,
          title: event.title,
          startsAt: event.startsAt,
          endsAt: event.endsAt,
          status: event.status,
          capacity: event.capacity,
          venue: { address: event.venue.address, city: event.venue.city },
        },
      });
    }

    return { items, nextCursor: page.nextCursor };
  }
}
