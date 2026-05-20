import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { ReviewRepository } from '../../domain/repositories/review.repository.js';

export interface HideReviewInput {
  moderatorUserId: string;
  reviewId: string;
  reportId: string;
  reason: string;
}

/**
 * Hide a review following a moderation decision.
 *
 * Invoked from the admin CLI (Brief 3B). NOT exposed via HTTP in this brief.
 * The moderation flow: a report is filed → reviewed by a moderator →
 * moderator calls this use case → review.hidden=true.
 *
 * Idempotent: hiding an already-hidden review is a no-op (no second event).
 */
export class HideReviewUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly reviews: ReviewRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: HideReviewInput): Promise<void> {
    const review = await this.reviews.findById(input.reviewId);
    if (!review) {
      throw AppError.notFound('Review not found');
    }

    const now = this.clock.now();
    review.hide({
      hiddenByUserId: input.moderatorUserId,
      reportId: input.reportId,
      reason: input.reason,
      now,
    });

    const events = review.pullEvents();
    if (events.length === 0) {
      // Already hidden — idempotent no-op.
      return;
    }

    await this.unitOfWork.run(async (ctx) => {
      await this.reviews.save(review, ctx);
      await this.publisher.publish(ctx, ...events);
    });
  }
}
