import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { UserCapabilitiesPort } from '@/features/users/application/ports/user-capabilities.port.js';
import { Event, type ApprovalMode } from '../../domain/entities/event.js';
import { privateVenueAttempted } from '../../domain/events/private-venue-attempted.event.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';
import { detectPrivateVenue } from '../../domain/services/private-venue-policy.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
import { VenueCategory } from '../../domain/value-objects/venue-category.js';
import { Venue } from '../../domain/value-objects/venue.js';

export interface CreateEventInput {
  hostUserId: string;
  title: string;
  description: string | null;
  venue: { address: string; city: string; latitude: number; longitude: number };
  startsAt: Date;
  endsAt: Date;
  capacity: number;
  category: string;
  venueCategory: string;
  costNotes: string | null;
  approvalMode: ApprovalMode;
}

/**
 * Create a new Event for the authenticated host. POST /events behaviour:
 * the aggregate is created (status='draft') and immediately published
 * (status='published') in the same use case + the same transaction. Both
 * `events.eventCreated` and `events.eventPublished` are emitted atomically
 * with the row insert.
 *
 * Rationale: TRI-19 ships no separate publish endpoint, so creating an event
 * is conceptually a "publish a new event" action for callers. A draft
 * workflow (multi-step form save/resume) can ship later by splitting the
 * POST into two endpoints — no migration required.
 *
 * Public-venue enforcement (TRI-33): first-time hosts (canPostPrivateVenue=false)
 * may not use private-category or private-keyword venues. Attempting to do so
 * publishes a `events.privateVenueAttempted` audit event then throws 422.
 */
export class CreateEventUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly events: EventRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
    private readonly getUserCapabilities: UserCapabilitiesPort,
  ) {}

  async execute(input: CreateEventInput): Promise<Event> {
    const venue = Venue.create(input.venue);
    const capacity = Capacity.create(input.capacity);
    const category = EventCategory.create(input.category);
    // VenueCategory.create throws AppError.validation on invalid value — policy check below
    // only runs if this passes, so invalid category produces 400 before 422.
    const venueCategory = VenueCategory.create(input.venueCategory);

    const detection = detectPrivateVenue({
      category: venueCategory,
      venueName: input.venue.address,
    });

    if (detection.isPrivate) {
      const caps = await this.getUserCapabilities.execute({ userId: input.hostUserId });
      if (!caps.canPostPrivateVenue) {
        // detection.reason is guaranteed non-null when isPrivate=true (policy invariant),
        // but the union type carries null for the not-private branch. Guard defensively.
        const reason = detection.reason ?? 'category_not_public';
        const now = this.clock.now();
        const policyRejectionId = createId();
        await this.unitOfWork.run(async (ctx) => {
          await this.publisher.publish(
            ctx,
            privateVenueAttempted(
              {
                userId: input.hostUserId,
                attemptedVenueName: input.venue.address,
                attemptedVenueCategory: venueCategory.value,
                reason,
                matchedKeyword: detection.matchedKeyword,
                attemptedAt: now.toISOString(),
              },
              policyRejectionId,
            ),
          );
        });
        throw AppError.unprocessable('First event must be at a public meeting spot', {
          subcode: 'FIRST_EVENT_MUST_BE_PUBLIC',
          reason,
        });
      }
    }

    const now = this.clock.now();
    const event = Event.create({
      id: createId(),
      hostUserId: input.hostUserId,
      title: input.title,
      description: input.description,
      venue,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      capacity,
      category,
      venueCategory,
      costNotes: input.costNotes,
      approvalMode: input.approvalMode,
      now,
    });
    event.publish(now);

    await this.unitOfWork.run(async (ctx) => {
      await this.events.save(event, ctx);
      await this.publisher.publish(ctx, ...event.pullEvents());
    });

    return event;
  }
}
