import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { AppError } from '@/core/errors/app-error.js';
import { reviewEdited } from '../events/review-edited.event.js';
import { reviewHidden } from '../events/review-hidden.event.js';
import { reviewSubmitted } from '../events/review-submitted.event.js';
import type { Rating } from '../value-objects/rating.js';
import type { ReviewComment } from '../value-objects/review-comment.js';

/** 24 hours in milliseconds — the window during which a review can be edited. */
const EDIT_WINDOW_MS = 24 * 60 * 60 * 1000;

/**
 * Review aggregate root — a single user's post-event assessment of another
 * participant in the same completed event.
 *
 * Lifecycle:
 *   - `Review.submit(...)` — new review. Records `reviews.reviewSubmitted`.
 *   - `review.edit(...)` — updates rating/comment within 24h of creation.
 *     Records `reviews.reviewEdited`.
 *   - `review.hide(...)` — moderator action after a report. Records
 *     `reviews.reviewHidden`.
 *
 * PDPA: comment text MUST NOT appear in emitted events. Events carry
 * `hasComment: boolean` only — the actual text stays in the reviews table
 * behind access control.
 *
 * Edit window: `canEdit(now)` is the public query; `edit()` throws
 * `ReviewEditWindowExpired` (CONFLICT, 409) when the window has closed.
 */
export class Review extends AggregateRoot {
  private constructor(
    public readonly id: string,
    public readonly eventId: string,
    public readonly raterUserId: string,
    public readonly ratedUserId: string,
    private _rating: Rating,
    private _comment: ReviewComment | null,
    public readonly createdAt: Date,
    private _updatedAt: Date,
    private _hidden: boolean,
    private _hiddenAt: Date | null,
    private _hiddenReason: string | null,
  ) {
    super();
  }

  // ---- Factories ----

  static submit(input: {
    id: string;
    eventId: string;
    raterUserId: string;
    ratedUserId: string;
    rating: Rating;
    comment: ReviewComment | null;
    now: Date;
  }): Review {
    const review = new Review(
      input.id,
      input.eventId,
      input.raterUserId,
      input.ratedUserId,
      input.rating,
      input.comment,
      input.now,
      input.now,
      false,
      null,
      null,
    );
    review.record(
      reviewSubmitted({
        reviewId: input.id,
        eventId: input.eventId,
        raterUserId: input.raterUserId,
        ratedUserId: input.ratedUserId,
        rating: input.rating.value,
        hasComment: input.comment !== null,
        createdAt: input.now.toISOString(),
      }),
    );
    return review;
  }

  static rehydrate(state: {
    id: string;
    eventId: string;
    raterUserId: string;
    ratedUserId: string;
    rating: Rating;
    comment: ReviewComment | null;
    createdAt: Date;
    updatedAt: Date;
    hidden: boolean;
    hiddenAt: Date | null;
    hiddenReason: string | null;
  }): Review {
    return new Review(
      state.id,
      state.eventId,
      state.raterUserId,
      state.ratedUserId,
      state.rating,
      state.comment,
      state.createdAt,
      state.updatedAt,
      state.hidden,
      state.hiddenAt,
      state.hiddenReason,
    );
  }

  // ---- Getters ----

  get rating(): Rating {
    return this._rating;
  }

  get comment(): ReviewComment | null {
    return this._comment;
  }

  get updatedAt(): Date {
    return this._updatedAt;
  }

  get hidden(): boolean {
    return this._hidden;
  }

  get hiddenAt(): Date | null {
    return this._hiddenAt;
  }

  get hiddenReason(): string | null {
    return this._hiddenReason;
  }

  // ---- Queries ----

  /**
   * Returns true if the review is still within the 24h edit window.
   * Pure function — no side effects.
   */
  canEdit(now: Date): boolean {
    return now.getTime() - this.createdAt.getTime() < EDIT_WINDOW_MS;
  }

  // ---- Commands ----

  /**
   * Edit the rating and/or comment. Only allowed within 24h of creation.
   *
   * Throws `AppError.conflict('reviews.editWindowExpired')` if the window
   * has closed — the subcode is the stable signal for the presentation layer.
   *
   * No-op if neither rating nor comment actually changed — no event emitted,
   * no updatedAt bump.
   */
  edit(input: { rating: Rating; comment: ReviewComment | null; now: Date }): void {
    if (!this.canEdit(input.now)) {
      throw AppError.conflict('Review edit window has expired', {
        subcode: 'reviews.editWindowExpired',
      });
    }

    const ratingChanged = !this._rating.equals(input.rating);
    const commentChanged =
      (this._comment === null) !== (input.comment === null) ||
      (this._comment !== null && input.comment !== null && !this._comment.equals(input.comment));

    if (!ratingChanged && !commentChanged) return;

    this._rating = input.rating;
    this._comment = input.comment;
    this._updatedAt = input.now;

    this.record(
      reviewEdited({
        reviewId: this.id,
        eventId: this.eventId,
        raterUserId: this.raterUserId,
        ratedUserId: this.ratedUserId,
        rating: this._rating.value,
        hasComment: this._comment !== null,
        editedAt: input.now.toISOString(),
      }),
    );
  }

  /**
   * Hide the review following a moderation decision. Sets `hidden=true` and
   * records the moderator, report, and reason for the audit trail.
   *
   * Idempotent: hiding an already-hidden review is a no-op (no second event).
   */
  hide(input: { hiddenByUserId: string; reportId: string; reason: string; now: Date }): void {
    if (this._hidden) return;

    this._hidden = true;
    this._hiddenAt = input.now;
    this._hiddenReason = input.reason;
    this._updatedAt = input.now;

    this.record(
      reviewHidden({
        reviewId: this.id,
        eventId: this.eventId,
        raterUserId: this.raterUserId,
        ratedUserId: this.ratedUserId,
        hiddenByUserId: input.hiddenByUserId,
        reportId: input.reportId,
        reason: input.reason,
        hiddenAt: input.now.toISOString(),
      }),
    );
  }
}
