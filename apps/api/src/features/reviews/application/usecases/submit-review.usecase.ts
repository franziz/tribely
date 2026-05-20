import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { JoinRequestRepository } from '@/features/join-requests/domain/repositories/join-request.repository.js';
import { Review } from '../../domain/entities/review.js';
import type { ReviewRepository } from '../../domain/repositories/review.repository.js';
import { Rating } from '../../domain/value-objects/rating.js';
import { ReviewComment } from '../../domain/value-objects/review-comment.js';

export interface SubmitReviewInput {
  raterUserId: string;
  eventId: string;
  ratedUserId: string;
  rating: number;
  comment?: string;
}

/**
 * Submit a review for another participant in a completed event.
 *
 * Eligibility guards (all throw 403 FORBIDDEN with structured subcodes):
 *   - Event must exist and be status='completed'.
 *   - raterUserId !== ratedUserId (no self-reviews).
 *   - Exactly one of the pair must be the host; the other must have an
 *     approved join request for the event. Both directions are allowed:
 *     host rates guest OR guest rates host.
 *   - No existing review with the same (eventId, raterUserId, ratedUserId)
 *     triple (throws 409 ALREADY_REVIEWED).
 */
export class SubmitReviewUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly reviews: ReviewRepository,
    private readonly events: EventRepository,
    private readonly joinRequests: JoinRequestRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: SubmitReviewInput): Promise<Review> {
    // Build VOs first — throw before any side effects if invalid.
    const rating = Rating.create(input.rating);
    const comment = input.comment !== undefined ? ReviewComment.create(input.comment) : null;

    const event = await this.events.findById(input.eventId);
    if (!event) {
      throw AppError.notFound('Event not found');
    }
    if (event.status !== 'completed') {
      throw AppError.forbidden('Reviews can only be submitted for completed events', {
        subcode: 'reviews.eventNotCompleted',
      });
    }

    if (input.raterUserId === input.ratedUserId) {
      throw AppError.forbidden('Cannot review yourself', {
        subcode: 'reviews.selfReview',
      });
    }

    // Eligibility: one must be the host; the other must have an approved
    // join request. Both host→guest and guest→host directions allowed.
    const isHostRatingGuest = event.hostUserId === input.raterUserId;
    const isGuestRatingHost = event.hostUserId === input.ratedUserId;

    if (!isHostRatingGuest && !isGuestRatingHost) {
      throw AppError.forbidden('Rater is not a participant in this event', {
        subcode: 'reviews.notParticipant',
      });
    }

    // The non-host party must have an approved join request.
    const guestUserId = isHostRatingGuest ? input.ratedUserId : input.raterUserId;
    const approvedRequests = await this.joinRequests.findByEvent(input.eventId, {
      requesterUserId: guestUserId,
      status: ['approved'],
    });

    if (approvedRequests.length === 0) {
      throw AppError.forbidden('No approved join request found for this pair', {
        subcode: 'reviews.noApprovedPair',
      });
    }

    // Check for duplicate review.
    const existing = await this.reviews.findByTriple({
      eventId: input.eventId,
      raterUserId: input.raterUserId,
      ratedUserId: input.ratedUserId,
    });
    if (existing) {
      throw AppError.conflict('Review already exists for this event and pair', {
        subcode: 'reviews.alreadyReviewed',
      });
    }

    const now = this.clock.now();
    const review = Review.submit({
      id: createId(),
      eventId: input.eventId,
      raterUserId: input.raterUserId,
      ratedUserId: input.ratedUserId,
      rating,
      comment,
      now,
    });

    await this.unitOfWork.run(async (ctx) => {
      await this.reviews.save(review, ctx);
      await this.publisher.publish(ctx, ...review.pullEvents());
    });

    return review;
  }
}
