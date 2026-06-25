import { z } from 'zod';
import { EventCategory } from '../../../domain/value-objects/event-category.js';
import { VenueCategory } from '../../../domain/value-objects/venue-category.js';

// ---- Shared sub-schemas ----

const venueSchema = z.object({
  address: z.string().min(1).max(300),
  city: z.string().min(1).max(120),
  latitude: z.number().finite().min(-90).max(90),
  longitude: z.number().finite().min(-180).max(180),
  category: z.enum(VenueCategory.VALUES),
});

const approvalModeSchema = z.enum(['auto', 'manual']);
const categorySchema = z.enum(EventCategory.VALUES);

const isoDatetime = z.string().datetime({ offset: true });

// ---- Bodies ----

export const createEventBodySchema = z
  .object({
    title: z.string().min(3).max(120),
    description: z.string().max(2000).nullable().optional(),
    venue: venueSchema,
    startsAt: isoDatetime,
    endsAt: isoDatetime,
    capacity: z.number().int().min(2).max(1000),
    category: categorySchema,
    costNotes: z.string().max(200).nullable().optional(),
    coverPhotoStorageKey: z.string().min(1).nullable().optional(),
    approvalMode: approvalModeSchema,
  })
  .refine((v) => new Date(v.endsAt).getTime() > new Date(v.startsAt).getTime(), {
    message: 'endsAt must be after startsAt',
    path: ['endsAt'],
  });

export const updateEventBodySchema = z
  .object({
    title: z.string().min(3).max(120).optional(),
    description: z.string().max(2000).nullable().optional(),
    venue: venueSchema.optional(),
    startsAt: isoDatetime.optional(),
    endsAt: isoDatetime.optional(),
    capacity: z.number().int().min(2).max(1000).optional(),
    category: categorySchema.optional(),
    costNotes: z.string().max(200).nullable().optional(),
    approvalMode: approvalModeSchema.optional(),
  })
  .refine((v) => Object.values(v).some((field) => field !== undefined), {
    message: 'At least one field must be provided',
  });

export const cancelEventBodySchema = z.object({
  reason: z.string().max(500).optional(),
});

// ---- Query ----

export const listEventsQuerySchema = z.object({
  city: z.string().min(1).max(120).optional(),
  category: categorySchema.optional(),
  from: isoDatetime.optional(),
  to: isoDatetime.optional(),
  /**
   * Filter by host. Accepts a concrete user id (for admin/moderation use cases).
   * The `'me'` sentinel is NOT supported — callers that want their own hosted
   * events must use `GET /me/events`.
   */
  hostUserId: z.string().min(1).optional(),
  cursor: z.string().min(1).optional(),
  // `coerce` lets the query string `?limit=20` arrive as a string and parse to
  // a number. The integer + clamp constraint stays.
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

// ---- Responses ----

const eventResponseSchema = z.object({
  id: z.string(),
  hostUserId: z.string(),
  title: z.string(),
  description: z.string().nullable(),
  venue: venueSchema,
  startsAt: z.string(),
  endsAt: z.string(),
  capacity: z.number(),
  category: categorySchema,
  costNotes: z.string().nullable(),
  coverPhotoUrl: z.string().url().nullable(),
  approvalMode: approvalModeSchema,
  status: z.enum(['draft', 'published', 'cancelled', 'completed']),
  cancellationReason: z.string().nullable(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export const eventWithHostResponseSchema = z.object({
  event: eventResponseSchema,
  host: z.object({ id: z.string(), displayName: z.string(), isVerified: z.boolean() }),
});

export const eventListingResponseSchema = z.object({
  events: z.array(eventResponseSchema),
  nextCursor: z.string().nullable(),
});

// ---- Inferred types ----

export type CreateEventBody = z.infer<typeof createEventBodySchema>;
export type UpdateEventBody = z.infer<typeof updateEventBodySchema>;
export type CancelEventBody = z.infer<typeof cancelEventBodySchema>;
export type ListEventsQuery = z.infer<typeof listEventsQuerySchema>;
export type EventResponse = z.infer<typeof eventResponseSchema>;
export type EventWithHostResponse = z.infer<typeof eventWithHostResponseSchema>;
export type EventListingResponse = z.infer<typeof eventListingResponseSchema>;
