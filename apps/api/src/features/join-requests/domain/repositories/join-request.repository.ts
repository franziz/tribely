import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { JoinRequest } from '../entities/join-request.js';

/**
 * Filters for listing join requests inside an event. Today only
 * `requesterUserId` is supported (so a host can scope to one user, or so
 * the requester can fetch their own row); status filtering is the caller's
 * job to keep this interface narrow. Add fields here as new use cases arrive.
 */
export interface ListJoinRequestsFilters {
  requesterUserId?: string;
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
}
