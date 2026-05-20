import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { CheckBlockedPort } from '@/features/user-blocks/application/ports/check-blocked.port.js';
import type { ReviewRepository } from '../../domain/repositories/review.repository.js';
import { reviewVisibilityProjection } from '../projections/review-visibility.projection.js';
import type {
  ListReviewsForUserResult,
  ReviewForUserRow,
} from '../dto/list-reviews-for-user-result.dto.js';

export type { ListReviewsForUserResult, ReviewForUserRow };

export interface ListReviewsForUserInput {
  viewerId: string;
  targetUserId: string;
  cursor?: string;
  limit?: number;
}

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

/**
 * List reviews about `targetUserId` as seen by `viewerId`.
 *
 * Applies `ReviewVisibilityProjection` per row:
 *   - `'visible'` → full content.
 *   - `'blind-mutual-pending'` → `{ rating: null, comment: null,
 *     hiddenForMutualWindow: true }`. The content is hidden until the
 *     counterpart posts their review (or 14 days pass).
 *   - `'hidden'` where `viewer === author` → included with `{ hidden: true }`.
 *   - `'hidden'` where `viewer !== author` → excluded from response.
 *
 * Block filter: rater IDs that are blocked by (or have blocked) viewerId are
 * excluded. Currently a no-op (Brief 1C replaces the stub binding).
 */
export class ListReviewsForUserUseCase {
  constructor(
    private readonly reviews: ReviewRepository,
    private readonly checkBlocked: CheckBlockedPort,
    private readonly clock: Clock,
  ) {}

  async execute(input: ListReviewsForUserInput): Promise<ListReviewsForUserResult> {
    const limit = Math.min(input.limit ?? DEFAULT_LIMIT, MAX_LIMIT);

    const { rows: rawRows, nextCursor } = await this.reviews.listByRatedUser({
      ratedUserId: input.targetUserId,
      viewerId: input.viewerId,
      ...(input.cursor ? { cursor: this.decodeCursor(input.cursor) } : {}),
      limit,
    });

    if (rawRows.length === 0) {
      return { rows: [], nextCursor };
    }

    // Block filter — filter out raters blocked by/of the viewer.
    const raterIds = rawRows.map((r) => r.review.raterUserId);
    const blockedSet = await this.checkBlocked.filterBlocked({
      viewerId: input.viewerId,
      candidateIds: raterIds,
    });

    const now = this.clock.now();
    const result: ReviewForUserRow[] = [];

    for (const row of rawRows) {
      const { review, counterpartExists, eventCompletedAt } = row;

      // Block filter.
      if (blockedSet.has(review.raterUserId)) continue;

      const visibility = reviewVisibilityProjection({
        review,
        viewerId: input.viewerId,
        counterpartExists,
        eventCompletedAt,
        now,
      });

      if (visibility === 'hidden') {
        // Hidden rows: only show to the review author.
        if (input.viewerId !== review.raterUserId) continue;
        result.push({
          id: review.id,
          eventId: review.eventId,
          raterUserId: review.raterUserId,
          ratedUserId: review.ratedUserId,
          rating: review.rating.value,
          comment: review.comment?.value ?? null,
          hidden: true,
          hiddenForMutualWindow: false,
          createdAt: review.createdAt.toISOString(),
          updatedAt: review.updatedAt.toISOString(),
        });
        continue;
      }

      if (visibility === 'blind-mutual-pending') {
        result.push({
          id: review.id,
          eventId: review.eventId,
          raterUserId: review.raterUserId,
          ratedUserId: review.ratedUserId,
          rating: null,
          comment: null,
          hidden: false,
          hiddenForMutualWindow: true,
          createdAt: review.createdAt.toISOString(),
          updatedAt: review.updatedAt.toISOString(),
        });
        continue;
      }

      // 'visible'
      result.push({
        id: review.id,
        eventId: review.eventId,
        raterUserId: review.raterUserId,
        ratedUserId: review.ratedUserId,
        rating: review.rating.value,
        comment: review.comment?.value ?? null,
        hidden: false,
        hiddenForMutualWindow: false,
        createdAt: review.createdAt.toISOString(),
        updatedAt: review.updatedAt.toISOString(),
      });
    }

    return { rows: result, nextCursor };
  }

  private decodeCursor(raw: string): { lastCreatedAt: Date; lastReviewId: string } {
    try {
      const decoded: unknown = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
      if (
        typeof decoded !== 'object' ||
        decoded === null ||
        typeof (decoded as { lastCreatedAt: unknown }).lastCreatedAt !== 'string' ||
        typeof (decoded as { lastReviewId: unknown }).lastReviewId !== 'string'
      ) {
        throw new Error('shape');
      }
      const { lastCreatedAt, lastReviewId } = decoded as {
        lastCreatedAt: string;
        lastReviewId: string;
      };
      const at = new Date(lastCreatedAt);
      if (Number.isNaN(at.getTime())) throw new Error('date');
      return { lastCreatedAt: at, lastReviewId };
    } catch {
      // Malformed cursor → treat as no cursor (start from beginning).
      return { lastCreatedAt: new Date(0), lastReviewId: '' };
    }
  }
}
