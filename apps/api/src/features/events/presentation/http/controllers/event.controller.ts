import type { Context } from 'hono';
import { AppError } from '@/core/errors/app-error.js';
import type { Event } from '../../../domain/entities/event.js';
import type { ListEventsCursor } from '../../../domain/repositories/event.repository.js';
import type { CancelEventUseCase } from '../../../application/usecases/cancel-event.usecase.js';
import type { CreateEventUseCase } from '../../../application/usecases/create-event.usecase.js';
import type { GetEventUseCase } from '../../../application/usecases/get-event.usecase.js';
import type { ListEventsUseCase } from '../../../application/usecases/list-events.usecase.js';
import type { UpdateEventUseCase } from '../../../application/usecases/update-event.usecase.js';
import type {
  CancelEventBody,
  CreateEventBody,
  EventListingResponse,
  EventResponse,
  EventWithHostResponse,
  ListEventsQuery,
  UpdateEventBody,
} from '../schemas/event.schemas.js';

const toEventResponse = (event: Event): EventResponse => ({
  id: event.id,
  hostUserId: event.hostUserId,
  title: event.title,
  description: event.description,
  venue: {
    address: event.venue.address,
    city: event.venue.city,
    latitude: event.venue.latitude,
    longitude: event.venue.longitude,
    category: event.venueCategory.value,
  },
  startsAt: event.startsAt.toISOString(),
  endsAt: event.endsAt.toISOString(),
  capacity: event.capacity.value,
  category: event.category.value,
  costSplit: event.costSplit,
  approvalMode: event.approvalMode,
  status: event.status,
  cancellationReason: event.cancellationReason,
  createdAt: event.createdAt.toISOString(),
  updatedAt: event.updatedAt.toISOString(),
});

/**
 * Encode a keyset cursor as a base64 JSON string. Opaque to the client —
 * callers should pass it back verbatim. We don't sign it because exposing
 * `(startsAt, id)` to the user is harmless (they could compose the same
 * payload by reading the response), and a signed cursor adds rotation
 * complexity for no security gain.
 */
const encodeCursor = (cursor: ListEventsCursor): string =>
  Buffer.from(
    JSON.stringify({
      lastStartsAt: cursor.lastStartsAt.toISOString(),
      lastEventId: cursor.lastEventId,
    }),
    'utf8',
  ).toString('base64url');

const decodeCursor = (raw: string): ListEventsCursor => {
  try {
    const decoded: unknown = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
    if (
      typeof decoded !== 'object' ||
      decoded === null ||
      !('lastStartsAt' in decoded) ||
      !('lastEventId' in decoded) ||
      typeof (decoded as { lastStartsAt: unknown }).lastStartsAt !== 'string' ||
      typeof (decoded as { lastEventId: unknown }).lastEventId !== 'string'
    ) {
      throw new Error('shape');
    }
    const { lastStartsAt, lastEventId } = decoded as {
      lastStartsAt: string;
      lastEventId: string;
    };
    const at = new Date(lastStartsAt);
    if (Number.isNaN(at.getTime())) throw new Error('date');
    return { lastStartsAt: at, lastEventId };
  } catch {
    throw AppError.validation('Invalid cursor');
  }
};

export class EventController {
  constructor(
    private readonly createEvent: CreateEventUseCase,
    private readonly listEvents: ListEventsUseCase,
    private readonly getEvent: GetEventUseCase,
    private readonly updateEvent: UpdateEventUseCase,
    private readonly cancelEvent: CancelEventUseCase,
  ) {}

  createAction = async (c: Context, hostUserId: string, body: CreateEventBody) => {
    const { category: venueCategory, ...venueFields } = body.venue;
    const event = await this.createEvent.execute({
      hostUserId,
      title: body.title,
      description: body.description ?? null,
      venue: venueFields,
      startsAt: new Date(body.startsAt),
      endsAt: new Date(body.endsAt),
      capacity: body.capacity,
      category: body.category,
      venueCategory,
      costSplit: body.costSplit,
      approvalMode: body.approvalMode,
    });
    return c.json(toEventResponse(event), 201);
  };

  /**
   * Public event listing. `GET /events`.
   * `hostUserId` query param accepts a concrete user id for admin/moderation
   * use cases. The `'me'` sentinel is NOT supported here — callers that want
   * their own hosted events must use `GET /me/events` (requireAuth route).
   */
  listAction = async (c: Context, query: ListEventsQuery) => {
    const result = await this.listEvents.execute({
      ...(query.city !== undefined && { city: query.city }),
      ...(query.category !== undefined && { category: query.category }),
      ...(query.from !== undefined && { from: new Date(query.from) }),
      ...(query.to !== undefined && { to: new Date(query.to) }),
      ...(query.hostUserId !== undefined && { hostUserId: query.hostUserId }),
      ...(query.cursor !== undefined && { cursor: decodeCursor(query.cursor) }),
      limit: query.limit,
    });
    const response: EventListingResponse = {
      events: result.events.map(toEventResponse),
      nextCursor: result.nextCursor ? encodeCursor(result.nextCursor) : null,
    };
    return c.json(response, 200);
  };

  /**
   * Authenticated user's own hosted events. `GET /me/events`.
   * Returns the same EventListingResponse shape as listAction.
   * No cursor/filter support — returns up to 50 events (max page size).
   * The mobile Hosting tab doesn't paginate; this matches the existing
   * mobile pattern for "list my join requests" which also fetches all at once.
   */
  listMyEventsAction = async (c: Context, actorUserId: string) => {
    const result = await this.listEvents.execute({
      hostUserId: actorUserId,
      limit: 50,
    });
    const response: EventListingResponse = {
      events: result.events.map(toEventResponse),
      nextCursor: result.nextCursor ? encodeCursor(result.nextCursor) : null,
    };
    return c.json(response, 200);
  };

  getAction = async (c: Context, id: string) => {
    const result = await this.getEvent.execute({ id });
    const response: EventWithHostResponse = {
      event: toEventResponse(result.event),
      host: result.host,
    };
    return c.json(response, 200);
  };

  updateAction = async (c: Context, id: string, actorUserId: string, body: UpdateEventBody) => {
    // When `body.venue` is supplied, extract `category` (→ venueCategory in use case)
    // and pass the remaining fields as the venue location shape.
    const venueFields =
      body.venue !== undefined
        ? {
            address: body.venue.address,
            city: body.venue.city,
            latitude: body.venue.latitude,
            longitude: body.venue.longitude,
          }
        : undefined;
    const venueCategoryFromVenue = body.venue !== undefined ? body.venue.category : undefined;

    const event = await this.updateEvent.execute({
      eventId: id,
      actorUserId,
      patch: {
        ...(body.title !== undefined && { title: body.title }),
        ...(body.description !== undefined && { description: body.description }),
        ...(venueFields !== undefined && { venue: venueFields }),
        ...(body.startsAt !== undefined && { startsAt: new Date(body.startsAt) }),
        ...(body.endsAt !== undefined && { endsAt: new Date(body.endsAt) }),
        ...(body.capacity !== undefined && { capacity: body.capacity }),
        ...(body.category !== undefined && { category: body.category }),
        ...(venueCategoryFromVenue !== undefined && { venueCategory: venueCategoryFromVenue }),
        ...(body.costSplit !== undefined && { costSplit: body.costSplit }),
        ...(body.approvalMode !== undefined && { approvalMode: body.approvalMode }),
      },
    });
    return c.json(toEventResponse(event), 200);
  };

  cancelAction = async (c: Context, id: string, actorUserId: string, body: CancelEventBody) => {
    await this.cancelEvent.execute({
      eventId: id,
      actorUserId,
      reason: body.reason ?? null,
    });
    return c.body(null, 204);
  };
}
