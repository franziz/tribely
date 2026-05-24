import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Review } from '../entities/review.js';

/**
 * Keyset cursor for `listByRatedUser`. Encodes `(createdAt, id)` position
 * of the last item on the previous page. Callers treat this as opaque;
 * the infra layer produces and consumes it.
 */
export interface ListByRatedUserCursor {
  lastCreatedAt: Date;
  lastReviewId: string;
}

/**
 * A row returned by `listByRatedUser`, enriched with the counterpart-existence
 * flag (for the blind mutual window) and the event completion timestamp (for
 * the 14-day visibility fallback).
 */
export interface ReviewWithVisibilityContext {
  review: Review;
  /** True if the counterpart review (rated user reviewing back) also exists. */
  counterpartExists: boolean;
  /** `endsAt` of the parent event — used by the visibility projection. */
  eventCompletedAt: Date;
}

/**
 * A slim struct for the aggregated profile summary returned by
 * `aggregateForUser`. Comment text is excerpt-only (first 100 chars) since
 * this is a public read model.
 */
export interface ReviewAggregateForUser {
  averageRating: number | null;
  reviewCount: number;
  recentVisibleComments: Array<{
    excerpt: string;
    raterDisplayName: string;
    rating: number;
    eventTitle: string;
    createdAt: Date;
  }>;
}

/**
 * Repository for the Review aggregate.
 *
 * All methods accept an optional `ctx?: TxContext` so the use case layer can
 * compose reads and writes inside a single transaction where required.
 *
 * `listByRatedUser` and `aggregateForUser` apply the mutual-window visibility
 * rules, block filter, and hidden exclusion at the READ layer so the use case
 * doesn't need to issue N+1 follow-up queries.
 */
export interface ReviewRepository {
  save(review: Review, ctx?: TxContext): Promise<void>;

  findById(id: string, ctx?: TxContext): Promise<Review | null>;

  /**
   * Find the unique review for a given (eventId, raterUserId, ratedUserId)
   * triple. Returns `null` if none exists.
   */
  findByTriple(
    input: { eventId: string; raterUserId: string; ratedUserId: string },
    ctx?: TxContext,
  ): Promise<Review | null>;

  /**
   * Cursor-paginated listing of reviews about `ratedUserId`, with each row
   * enriched by:
   *   - `counterpartExists`: whether ratedUserId has also reviewed raterUserId
   *     for the same event (drives blind mutual window).
   *   - `eventCompletedAt`: the event's `endsAt` (proxy for completion time,
   *     used by the 14-day visibility fallback).
   *
   * The implementation MUST resolve `counterpartExists` in a single batched
   * SQL (NOT per-row sub-queries) to avoid N+1 performance degradation.
   *
   * Hidden reviews ARE included (visibility projection in the use case
   * decides whether to show them to the viewer).
   *
   * Ordered `createdAt DESC, id DESC`. Default limit: 20, max: 100.
   */
  listByRatedUser(
    input: {
      ratedUserId: string;
      viewerId: string;
      cursor?: ListByRatedUserCursor;
      limit?: number;
    },
    ctx?: TxContext,
  ): Promise<{
    rows: ReadonlyArray<ReviewWithVisibilityContext>;
    nextCursor: string | null;
  }>;

  /**
   * Cursor-paginated listing of reviews written by `raterUserId`.
   * Returns all reviews including hidden ones (the author can always see
   * their own reviews — the `hidden` flag is the signal for the UI).
   *
   * Ordered `createdAt DESC, id DESC`.
   */
  listWrittenBy(
    input: { raterUserId: string; cursor?: string; limit?: number },
    ctx?: TxContext,
  ): Promise<{ rows: Review[]; nextCursor: string | null }>;

  /**
   * Batch-lookup: returns the subset of `(eventId, ratedUserId)` pairs from
   * `pairs` for which `raterUserId` has already submitted a review.
   *
   * Used by the pending-review-prompts use case to exclude already-reviewed
   * counterparts without issuing N+1 queries (one lookup per candidate pair).
   *
   * The returned Set contains strings in `"eventId:ratedUserId"` format for
   * O(1) membership testing by the caller.
   */
  findExistingTriples(
    input: {
      raterUserId: string;
      pairs: ReadonlyArray<{ eventId: string; ratedUserId: string }>;
    },
    ctx?: TxContext,
  ): Promise<Set<string>>;

  /**
   * Aggregate read model for a user's review profile.
   *
   * Applies at the read layer:
   *   - `review.hidden` exclusion (always applied)
   *   - block filter: reviews by raters that have a block relationship with
   *     `viewerId` are excluded from both count/average and `recentVisibleComments`
   *   - mutual-window visibility: reviews still in the blind mutual-window
   *     (counterpart review absent AND < 14 days since event completion)
   *     are excluded from `recentVisibleComments` but ARE counted in
   *     `reviewCount` and `averageRating` once the window expires or the
   *     counterpart submits
   *
   * Returns `averageRating=null` when `reviewCount=0`.
   * `recentVisibleComments` returns at most 3 entries (most recent visible).
   */
  aggregateForUser(
    input: { ratedUserId: string; viewerId: string },
    ctx?: TxContext,
  ): Promise<ReviewAggregateForUser>;

  /**
   * Bulk-delete all reviews where the given user is either the rater or the
   * rated party, as part of a PDPA erasure cascade on account deletion.
   *
   * Required ctx (non-optional) — this method MUST be invoked inside the
   * caller's UnitOfWork transaction to guarantee atomicity with the broader
   * account-deletion cascade.
   *
   * Returns the count of deleted rows.
   */
  deleteAllForUser(userId: string, ctx: TxContext): Promise<number>;
}
