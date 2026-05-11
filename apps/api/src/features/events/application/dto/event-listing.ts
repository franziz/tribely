import type { Event } from '../../domain/entities/event.js';
import type { ListEventsCursor } from '../../domain/repositories/event.repository.js';

/**
 * Result of {@link ListEventsUseCase.execute}. The use case keeps the cursor
 * shape symmetric with the repository (a `(startsAt, id)` tuple); the
 * presentation layer is responsible for encoding it as a base64 string on
 * the wire.
 */
export interface EventListingResult {
  events: Event[];
  nextCursor: ListEventsCursor | null;
}
