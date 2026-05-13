import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Event } from '@/features/events/domain/entities/event.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { JoinRequest, JoinRequestStatus } from '../entities/join-request.js';

/**
 * Filters for listing join requests inside an event.
 *
 * `requesterUserId` scopes to a single user (host scoping or requester self-view).
 *
 * `status` restricts to specific statuses; absent means no status restriction
 * (returns all statuses). Callers should supply an explicit value rather than
 * relying on repository-level defaults — the use case layer owns defaulting.
 */
export interface ListJoinRequestsFilters {
  requesterUserId?: string;
  status?: JoinRequestStatus[];
}

/**
 * Opaque keyset cursor for {@link JoinRequestRepository.listByRequester}.
 *
 * Encodes the `(requestedAt, id)` position of the last item on the previous
 * page. Callers treat this as an opaque blob; the infrastructure layer
 * produces and consumes it. The presentation layer encodes it as base64url
 * on the wire.
 */
export interface ListJoinRequestsByRequesterCursor {
  lastRequestedAt: Date;
  lastJoinRequestId: string;
}

/**
 * Page returned by {@link JoinRequestRepository.listByRequester}.
 */
export interface ListByRequesterPage {
  joinRequests: JoinRequest[];
  nextCursor: ListJoinRequestsByRequesterCursor | null;
}

/**
 * A join request paired with a lightweight event summary so the requester's
 * list-view can render title / time / venue without a second fetch.
 *
 * The `event` projection is intentionally narrow — only what the mobile
 * list-view needs. Add fields here only when a new consumer genuinely needs
 * them (don't inflate to the full Event aggregate).
 */
export interface JoinRequestWithEventSummary {
  joinRequest: JoinRequest;
  event: Pick<Event, 'id' | 'title' | 'startsAt' | 'endsAt' | 'status' | 'capacity'> & {
    venue: { address: string; city: string };
  };
}

/**
 * A join request paired with the requester's user record so the host-facing
 * list can render a name alongside each request without a second fetch.
 *
 * `requester` is the full User aggregate; the presentation layer projects
 * whatever fields it needs (currently only `id` + `displayName`).
 */
export interface JoinRequestWithRequester {
  joinRequest: JoinRequest;
  requester: User;
}

/**
 * Repository for the JoinRequest aggregate.
 *
 * Concurrency rules (enforced by the infrastructure impl, but documented here
 * so callers don't accidentally invent a racy flow):
 *   - Capacity-affecting writes (approve) MUST run inside a transaction that
 *     has already acquired `SELECT ... FOR UPDATE` on the parent Event row.
 *     `countApproved` therefore requires `ctx`. The DB partial unique index
 *     on (eventId, requesterUserId) WHERE status IN ('pending','approved')
 *     is the last-line defence against `request → request` races.
 *   - `findActiveByEventAndRequester` is the up-front check (returns a clean
 *     409 with the existing row id) before the race-loser falls through to
 *     the unique-violation path.
 */
export interface JoinRequestRepository {
  findById(id: string, ctx?: TxContext): Promise<JoinRequest | null>;

  /**
   * Returns the active (non-terminal) request for this (event, requester) pair,
   * or null. Used by RequestToJoinEventUseCase for a clean 409 before relying
   * on the DB unique violation as a fallback for race losers.
   */
  findActiveByEventAndRequester(
    eventId: string,
    requesterUserId: string,
    ctx?: TxContext,
  ): Promise<JoinRequest | null>;

  save(joinRequest: JoinRequest, ctx?: TxContext): Promise<void>;

  /**
   * Count approved requests for an event. Required for capacity enforcement.
   * Caller MUST be inside a transaction that has acquired SELECT FOR UPDATE
   * on the parent Event row — otherwise the count is racy.
   */
  countApproved(eventId: string, ctx: TxContext): Promise<number>;

  findByEvent(
    eventId: string,
    filters: ListJoinRequestsFilters,
    ctx?: TxContext,
  ): Promise<JoinRequest[]>;

  /**
   * Cursor-paginated listing of all join requests made by a given user,
   * optionally scoped to a single event (for "do I already have a request
   * for this event?" lookups on the mobile event-detail screen).
   *
   * Ordered `requestedAt DESC, id DESC` (newest first). The cursor is a
   * `(requestedAt, id)` keyset so pages stay stable under concurrent inserts.
   * Callers supply `limit + 1` rows implicitly — the impl takes `limit + 1`
   * and the caller checks `rows.length > limit` to derive `nextCursor`.
   */
  listByRequester(
    requesterUserId: string,
    eventId: string | undefined,
    cursor: ListJoinRequestsByRequesterCursor | null,
    limit: number,
    ctx?: TxContext,
  ): Promise<ListByRequesterPage>;
}
