import type { Review as ReviewRow, Prisma } from '@prisma/client';
import { Review } from '../../domain/entities/review.js';
import { Rating } from '../../domain/value-objects/rating.js';
import { ReviewComment } from '../../domain/value-objects/review-comment.js';

/**
 * Reconstruct a Review aggregate from a Prisma row.
 */
export const toReview = (row: ReviewRow): Review =>
  Review.rehydrate({
    id: row.id,
    eventId: row.eventId,
    raterUserId: row.raterUserId,
    ratedUserId: row.ratedUserId,
    rating: Rating.create(row.rating),
    comment: row.comment !== null ? ReviewComment.create(row.comment) : null,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    hidden: row.hidden,
    hiddenAt: row.hiddenAt,
    hiddenReason: row.hiddenReason,
  });

/**
 * Project a Review aggregate to a Prisma create input.
 */
export const toRow = (review: Review): Prisma.ReviewUncheckedCreateInput => ({
  id: review.id,
  eventId: review.eventId,
  raterUserId: review.raterUserId,
  ratedUserId: review.ratedUserId,
  rating: review.rating.value,
  comment: review.comment?.value ?? null,
  createdAt: review.createdAt,
  updatedAt: review.updatedAt,
  hidden: review.hidden,
  hiddenAt: review.hiddenAt,
  hiddenReason: review.hiddenReason,
});
