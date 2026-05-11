import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type {
  EventRepository,
  ListEventsCursor,
} from '../../domain/repositories/event.repository.js';
import type { EventListingResult } from '../dto/event-listing.js';

export interface ListEventsInput {
  city?: string;
  category?: string;
  from?: Date;
  to?: Date;
  cursor?: ListEventsCursor;
  limit: number;
}

/**
 * Read-only public feed query for GET /events. Translates user-supplied
 * filters into repository inputs and forwards them. No mutations, no events,
 * no UnitOfWork.
 */
export class ListEventsUseCase {
  constructor(
    private readonly events: EventRepository,
    private readonly clock: Clock,
  ) {}

  async execute(input: ListEventsInput): Promise<EventListingResult> {
    const page = await this.events.findManyForListing(
      {
        now: this.clock.now(),
        ...(input.city !== undefined && { city: input.city }),
        ...(input.category !== undefined && { category: input.category }),
        ...(input.from !== undefined && { from: input.from }),
        ...(input.to !== undefined && { to: input.to }),
      },
      input.cursor ?? null,
      input.limit,
    );
    return { events: page.events, nextCursor: page.nextCursor };
  }
}
