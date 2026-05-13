import { z } from 'zod';

// ---- Bodies ----

export const rejectJoinRequestBodySchema = z.object({
  reason: z.string().min(1).max(500),
});

// ---- Query ----

/**
 * Query params for `GET /me/join-requests`.
 * `eventId` scopes the listing to one event — used by mobile event-detail to
 * check for an existing request before showing a "Join" button.
 */
export const listMyJoinRequestsQuerySchema = z.object({
  eventId: z.string().min(1).optional(),
  cursor: z.string().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

// ---- Query: GET /events/:id/join-requests ----

/**
 * Query params for `GET /events/:id/join-requests`.
 *
 * `status` restricts results to the given status values. Repeated params
 * (`?status=pending&status=approved`) are the standard multi-value pattern in
 * this API. Defaults to `['pending']` at the use-case layer when absent.
 */
export const listJoinRequestsByEventQuerySchema = z.object({
  status: z
    .union([
      z.enum(['pending', 'approved', 'rejected', 'cancelled']),
      z.array(z.enum(['pending', 'approved', 'rejected', 'cancelled'])),
    ])
    .optional()
    .transform((v) => {
      if (v === undefined) return undefined;
      return Array.isArray(v) ? v : [v];
    }),
});

// ---- Shared sub-schema ----

const joinRequestStatusSchema = z.enum(['pending', 'approved', 'rejected', 'cancelled']);

export const joinRequestResponseSchema = z.object({
  id: z.string(),
  eventId: z.string(),
  requesterUserId: z.string(),
  status: joinRequestStatusSchema,
  requestedAt: z.string(),
  decidedAt: z.string().nullable(),
  decidedByUserId: z.string().nullable(),
  decisionReason: z.string().nullable(),
});

// ---- C1: GET /me/join-requests — requester's own requests with event summary ----

const joinRequestEventSummarySchema = z.object({
  id: z.string(),
  title: z.string(),
  startsAt: z.string(),
  endsAt: z.string(),
  venue: z.object({ address: z.string(), city: z.string() }),
  status: z.enum(['draft', 'published', 'cancelled', 'completed']),
  capacity: z.number(),
});

export const myJoinRequestsListResponseSchema = z.object({
  joinRequests: z.array(
    z.object({
      joinRequest: joinRequestResponseSchema,
      event: joinRequestEventSummarySchema,
    }),
  ),
  nextCursor: z.string().nullable(),
});

// ---- C2: GET /events/:id/join-requests — host view enriched with requester displayName ----

export const enrichedJoinRequestListResponseSchema = z.object({
  joinRequests: z.array(
    z.object({
      joinRequest: joinRequestResponseSchema,
      requester: z.object({ id: z.string(), displayName: z.string() }),
    }),
  ),
});

// ---- Inferred types ----

export type RejectJoinRequestBody = z.infer<typeof rejectJoinRequestBodySchema>;
export type ListMyJoinRequestsQuery = z.infer<typeof listMyJoinRequestsQuerySchema>;
export type ListJoinRequestsByEventQuery = z.infer<typeof listJoinRequestsByEventQuerySchema>;
export type JoinRequestResponse = z.infer<typeof joinRequestResponseSchema>;
export type MyJoinRequestsListResponse = z.infer<typeof myJoinRequestsListResponseSchema>;
export type EnrichedJoinRequestListResponse = z.infer<typeof enrichedJoinRequestListResponseSchema>;
