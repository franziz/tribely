import { z } from 'zod';

// ---- Bodies ----

/**
 * `POST /events/:id/join-requests` carries no body: `eventId` is in the path
 * and `requesterUserId` comes from the JWT. The empty `.strict()` schema is
 * exported anyway so the route can run the same validation pipeline as every
 * other endpoint (and to make adding a future opt-in field a one-line edit).
 */
export const createJoinRequestBodySchema = z.object({}).strict();

export const rejectJoinRequestBodySchema = z.object({
  reason: z.string().min(1).max(500),
});

// ---- Responses ----

const joinRequestStatusSchema = z.enum(['pending', 'approved', 'rejected', 'cancelled']);

const joinRequestResponseSchema = z.object({
  id: z.string(),
  eventId: z.string(),
  requesterUserId: z.string(),
  status: joinRequestStatusSchema,
  requestedAt: z.string(),
  decidedAt: z.string().nullable(),
  decidedByUserId: z.string().nullable(),
  decisionReason: z.string().nullable(),
});

export const joinRequestListResponseSchema = z.object({
  joinRequests: z.array(joinRequestResponseSchema),
});

// ---- Inferred types ----

export type CreateJoinRequestBody = z.infer<typeof createJoinRequestBodySchema>;
export type RejectJoinRequestBody = z.infer<typeof rejectJoinRequestBodySchema>;
export type JoinRequestResponse = z.infer<typeof joinRequestResponseSchema>;
export type JoinRequestListResponse = z.infer<typeof joinRequestListResponseSchema>;
