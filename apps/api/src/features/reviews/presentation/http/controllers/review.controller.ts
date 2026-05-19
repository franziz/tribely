import type { Context } from 'hono';
import type { EditReviewUseCase } from '../../../application/usecases/edit-review.usecase.js';
import type { ListReviewsForUserUseCase } from '../../../application/usecases/list-reviews-for-user.usecase.js';
import type { ListReviewsWrittenByMeUseCase } from '../../../application/usecases/list-reviews-written-by-me.usecase.js';
import type { SubmitReviewUseCase } from '../../../application/usecases/submit-review.usecase.js';
import type {
  EditReviewBody,
  ListReviewsQuery,
  SubmitReviewBody,
} from '../schemas/review.schemas.js';

export class ReviewController {
  constructor(
    private readonly submitReview: SubmitReviewUseCase,
    private readonly editReview: EditReviewUseCase,
    private readonly listReviewsForUser: ListReviewsForUserUseCase,
    private readonly listReviewsWrittenByMe: ListReviewsWrittenByMeUseCase,
  ) {}

  /**
   * POST /events/:eventId/reviews
   * Submits a review from the authenticated user for another participant in
   * the given event.
   */
  submitAction = async (
    c: Context,
    actorUserId: string,
    eventId: string,
    body: SubmitReviewBody,
  ) => {
    const review = await this.submitReview.execute({
      raterUserId: actorUserId,
      eventId,
      ratedUserId: body.ratedUserId,
      rating: body.rating,
      ...(body.comment !== undefined && { comment: body.comment }),
    });

    return c.json(
      {
        review: {
          id: review.id,
          eventId: review.eventId,
          raterUserId: review.raterUserId,
          ratedUserId: review.ratedUserId,
          rating: review.rating.value,
          comment: review.comment?.value ?? null,
          createdAt: review.createdAt.toISOString(),
          updatedAt: review.updatedAt.toISOString(),
        },
      },
      201,
    );
  };

  /**
   * PATCH /reviews/:reviewId
   * Edits the rating/comment within the 24h window.
   */
  editAction = async (c: Context, actorUserId: string, reviewId: string, body: EditReviewBody) => {
    await this.editReview.execute({
      raterUserId: actorUserId,
      reviewId,
      rating: body.rating,
      ...(body.comment !== undefined && { comment: body.comment }),
    });
    return c.body(null, 204);
  };

  /**
   * GET /users/:userId/reviews
   * List reviews about the target user as seen by the authenticated viewer.
   */
  listForUserAction = async (
    c: Context,
    actorUserId: string,
    targetUserId: string,
    query: ListReviewsQuery,
  ) => {
    const result = await this.listReviewsForUser.execute({
      viewerId: actorUserId,
      targetUserId,
      ...(query.cursor !== undefined && { cursor: query.cursor }),
      limit: query.limit,
    });
    return c.json(result, 200);
  };

  /**
   * GET /me/reviews/written
   * List reviews written by the authenticated user.
   */
  listWrittenAction = async (c: Context, actorUserId: string, query: ListReviewsQuery) => {
    const result = await this.listReviewsWrittenByMe.execute({
      raterUserId: actorUserId,
      ...(query.cursor !== undefined && { cursor: query.cursor }),
      limit: query.limit,
    });
    return c.json(result, 200);
  };
}
