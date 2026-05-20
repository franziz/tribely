import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Event } from '../entities/event.js';

/**
 * Filters accepted by {@link EventRepository.findManyForListing}.
 *
 * `now` is supplied by the caller (use case → injected `Clock`) rather than
 * read from `Date.now()` inside the repo, so tests stay deterministic and the
 * domain remains the source of truth for "what counts as past".
 */
export interface ListEventsFilters {
  city?: string;
  category?: string;
  from?: Date;
  to?: Date;
  now: Date;
  /** When set, restricts results to events hosted by this specific user. */
  hostUserId?: string;
}

/**
 * Keyset cursor for `findManyForListing`. The repository owns the predicate
 * shape (`(startsAt, id)` lexicographic ordering); the presentation layer is
 * responsible for encoding / decoding it as a base64 string on the wire.
 */
export interface ListEventsCursor {
  lastStartsAt: Date;
  lastEventId: string;
}

export interface ListEventsPage {
  events: Event[];
  nextCursor: ListEventsCursor | null;
}

/**
 * Repository for the Event aggregate.
 */
export interface EventRepository {
  findById(id: string, ctx?: TxContext): Promise<Event | null>;

  /**
   * Loads an Event with a `SELECT … FOR UPDATE` row lock. Required when the
   * caller needs to enforce an invariant that depends on counting child rows
   * (e.g., JoinRequest approval enforcing `approvedCount < capacity - 1`):
   * concurrent transactions targeting the same Event serialize at this lock,
   * preventing capacity violations.
   *
   * Unlike `findById`, this method REQUIRES a TxContext — `FOR UPDATE` outside
   * a transaction is meaningless (the lock would be released immediately).
   */
  findByIdForUpdate(id: string, ctx: TxContext): Promise<Event | null>;

  save(event: Event, ctx?: TxContext): Promise<void>;

  /**
   * Paginated query for the public discovery feed.
   *
   * Implementations MUST:
   *   - filter `status = 'published'` and `endsAt > filters.now` by default;
   *   - apply optional `city` (exact equality), `category` (exact equality),
   *     and `startsAt ∈ [from, to]` filters when supplied;
   *   - order by `startsAt ASC, id ASC` (lexicographic keyset);
   *   - honour `cursor` as a strict-greater-than predicate against the
   *     `(startsAt, id)` pair;
   *   - return at most `limit` events plus a `nextCursor` derived from the
   *     last returned row when there is a next page (null when exhausted).
   */
  findManyForListing(
    filters: ListEventsFilters,
    cursor: ListEventsCursor | null,
    limit: number,
    ctx?: TxContext,
  ): Promise<ListEventsPage>;

  /**
   * Returns the number of events with status `completed` hosted by the given
   * user. Used by the capabilities use case to determine whether a host has
   * earned private-venue posting access.
   */
  countCompletedByHost(hostUserId: string, ctx?: TxContext): Promise<number>;

  /**
   * Bulk-rewrites `hostUserId` to `pseudonymHostId` for every event hosted by
   * `userId`. Part of the PDPA erasure cascade — events remain queryable with
   * an opaque cuid2 pseudonym in place of the real user id.
   *
   * Required-ctx: caller MUST supply a TxContext so the rewrite commits
   * atomically with the rest of the account-deletion cascade.
   *
   * Returns the number of rows updated.
   */
  pseudonymiseHostForUser(userId: string, pseudonymHostId: string, ctx: TxContext): Promise<number>;
}
