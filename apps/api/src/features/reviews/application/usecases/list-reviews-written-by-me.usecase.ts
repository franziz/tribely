import type { ReviewRepository } from '../../domain/repositories/review.repository.js';

export interface ListReviewsWrittenByMeInput {
  raterUserId: string;
  cursor?: string;
  limit?: number;
}

export interface MyReviewRow {
  id: string;
  eventId: string;
  raterUserId: string;
  ratedUserId: string;
  rating: number;
  comment: string | null;
  hidden: boolean;
  hiddenAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ListReviewsWrittenByMeResult {
  rows: MyReviewRow[];
  nextCursor: string | null;
}

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

/**
 * List all reviews written by the authenticated user.
 *
 * Returns full content including hidden reviews with the `hidden: true` flag
 * so the mobile can render a notice explaining the review was removed from
 * the rated user's profile.
 */
export class ListReviewsWrittenByMeUseCase {
  constructor(private readonly reviews: ReviewRepository) {}

  async execute(input: ListReviewsWrittenByMeInput): Promise<ListReviewsWrittenByMeResult> {
    const limit = Math.min(input.limit ?? DEFAULT_LIMIT, MAX_LIMIT);

    const { rows: rawRows, nextCursor } = await this.reviews.listWrittenBy({
      raterUserId: input.raterUserId,
      ...(input.cursor !== undefined && { cursor: input.cursor }),
      limit,
    });

    const rows: MyReviewRow[] = rawRows.map((r) => ({
      id: r.id,
      eventId: r.eventId,
      raterUserId: r.raterUserId,
      ratedUserId: r.ratedUserId,
      rating: r.rating.value,
      comment: r.comment?.value ?? null,
      hidden: r.hidden,
      hiddenAt: r.hiddenAt?.toISOString() ?? null,
      createdAt: r.createdAt.toISOString(),
      updatedAt: r.updatedAt.toISOString(),
    }));

    return { rows, nextCursor };
  }
}
