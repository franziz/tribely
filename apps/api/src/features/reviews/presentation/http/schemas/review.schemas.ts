import { z } from 'zod';

// ---- Request bodies ----

export const submitReviewBodySchema = z.object({
  ratedUserId: z.string().min(1).max(100),
  rating: z.number().int().min(1).max(5),
  comment: z.string().max(500).optional(),
});

export const editReviewBodySchema = z.object({
  rating: z.number().int().min(1).max(5),
  comment: z.string().max(500).optional(),
});

// ---- Query params ----

export const listReviewsQuerySchema = z.object({
  cursor: z.string().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

// ---- Response shapes ----

const reviewRowSchema = z.object({
  id: z.string(),
  eventId: z.string(),
  raterUserId: z.string(),
  ratedUserId: z.string(),
  rating: z.number().nullable(),
  comment: z.string().nullable(),
  hidden: z.boolean(),
  hiddenForMutualWindow: z.boolean(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

const myReviewRowSchema = z.object({
  id: z.string(),
  eventId: z.string(),
  raterUserId: z.string(),
  ratedUserId: z.string(),
  rating: z.number(),
  comment: z.string().nullable(),
  hidden: z.boolean(),
  hiddenAt: z.string().nullable(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export const submitReviewResponseSchema = z.object({
  review: z.object({
    id: z.string(),
    eventId: z.string(),
    raterUserId: z.string(),
    ratedUserId: z.string(),
    rating: z.number(),
    comment: z.string().nullable(),
    createdAt: z.string(),
    updatedAt: z.string(),
  }),
});

export const listReviewsResponseSchema = z.object({
  rows: z.array(reviewRowSchema),
  nextCursor: z.string().nullable(),
});

export const listMyReviewsResponseSchema = z.object({
  rows: z.array(myReviewRowSchema),
  nextCursor: z.string().nullable(),
});

// ---- Inferred types ----

export type SubmitReviewBody = z.infer<typeof submitReviewBodySchema>;
export type EditReviewBody = z.infer<typeof editReviewBodySchema>;
export type ListReviewsQuery = z.infer<typeof listReviewsQuerySchema>;
export type SubmitReviewResponse = z.infer<typeof submitReviewResponseSchema>;
export type ListReviewsResponse = z.infer<typeof listReviewsResponseSchema>;
export type ListMyReviewsResponse = z.infer<typeof listMyReviewsResponseSchema>;
