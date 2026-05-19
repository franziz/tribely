import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { ReviewRepository } from '../../domain/repositories/review.repository.js';
import { Rating } from '../../domain/value-objects/rating.js';
import { ReviewComment } from '../../domain/value-objects/review-comment.js';

export interface EditReviewInput {
  raterUserId: string;
  reviewId: string;
  rating: number;
  comment?: string;
}

/**
 * Edit the rating and/or comment on an existing review within 24h of
 * submission.
 *
 * Error mapping:
 *   - 403 FORBIDDEN (`reviews.notAuthor`) — caller is not the review author.
 *   - 404 NOT_FOUND — review hidden or does not exist (hidden reviews return
 *     404 to non-authors; the review author receives 403 if trying to edit
 *     a hidden review — but the AC says 404 for hidden, so we unify to 404).
 *   - 409 CONFLICT (`reviews.editWindowExpired`) — 24h window has closed.
 *   - 400 VALIDATION_ERROR — invalid rating or comment.
 */
export class EditReviewUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly reviews: ReviewRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: EditReviewInput): Promise<void> {
    // Build VOs first — throw before any DB reads if invalid.
    const rating = Rating.create(input.rating);
    const comment = input.comment !== undefined ? ReviewComment.create(input.comment) : null;

    const review = await this.reviews.findById(input.reviewId);
    if (!review) {
      throw AppError.notFound('Review not found');
    }

    // Author check before hidden check — give authorship errors priority.
    if (review.raterUserId !== input.raterUserId) {
      throw AppError.forbidden('Not the author of this review', {
        subcode: 'reviews.notAuthor',
      });
    }

    // Hidden reviews are not editable even by the author.
    if (review.hidden) {
      throw AppError.notFound('Review not found');
    }

    const now = this.clock.now();
    review.edit({ rating, comment, now });

    await this.unitOfWork.run(async (ctx) => {
      await this.reviews.save(review, ctx);
      await this.publisher.publish(ctx, ...review.pullEvents());
    });
  }
}
