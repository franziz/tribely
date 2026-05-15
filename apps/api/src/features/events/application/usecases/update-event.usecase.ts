import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type {
  GetUserCapabilitiesUseCase,
  GetUserCapabilitiesResult,
} from '@/features/users/application/usecases/get-user-capabilities.usecase.js';

/** Structural slice used for DI — allows fakes in tests without concrete-class private-field issues. */
type CapabilitiesPort = Pick<GetUserCapabilitiesUseCase, 'execute'> & {
  execute(input: { userId: string }): Promise<GetUserCapabilitiesResult>;
};
import type { Event, ApprovalMode, CostSplit } from '../../domain/entities/event.js';
import { privateVenueAttempted } from '../../domain/events/private-venue-attempted.event.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';
import { detectPrivateVenue } from '../../domain/services/private-venue-policy.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
import { VenueCategory } from '../../domain/value-objects/venue-category.js';
import { Venue } from '../../domain/value-objects/venue.js';

export interface UpdateEventInput {
  eventId: string;
  actorUserId: string;
  patch: {
    title?: string;
    description?: string | null;
    venue?: { address: string; city: string; latitude: number; longitude: number };
    startsAt?: Date;
    endsAt?: Date;
    capacity?: number;
    category?: string;
    venueCategory?: string;
    costSplit?: CostSplit;
    approvalMode?: ApprovalMode;
  };
}

/**
 * Apply a host-supplied edit to an existing Event. Authorization: only the
 * host may edit. State guard: only `draft` and `published` events are
 * editable; the aggregate enforces that invariant.
 *
 * The aggregate handles the no-op case internally — if the patch matches
 * current state, no event is recorded and `updatedAt` is left alone.
 *
 * Public-venue enforcement (TRI-33): re-evaluation runs ONLY when the patch
 * touches `venue` or `venueCategory`. Title-only / capacity-only / date-only
 * patches do NOT invoke `getUserCapabilities` — no latency added, no
 * retro-enforcement on grandfathered rows.
 */
export class UpdateEventUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly events: EventRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
    private readonly getUserCapabilities: CapabilitiesPort,
  ) {}

  async execute(input: UpdateEventInput): Promise<Event> {
    const event = await this.events.findById(input.eventId);
    if (!event) throw AppError.notFound(`Event ${input.eventId} not found`);
    if (event.hostUserId !== input.actorUserId) {
      throw AppError.forbidden('Only the host may edit this event');
    }

    // Re-evaluate venue policy only when venue or venueCategory is being patched.
    const venueOrCategoryPatched =
      input.patch.venue !== undefined || input.patch.venueCategory !== undefined;

    if (venueOrCategoryPatched) {
      const nextVenueCategory =
        input.patch.venueCategory !== undefined
          ? VenueCategory.create(input.patch.venueCategory)
          : event.venueCategory;
      const nextVenueName = input.patch.venue?.address ?? event.venue.address;

      const detection = detectPrivateVenue({
        category: nextVenueCategory,
        venueName: nextVenueName,
      });

      if (detection.isPrivate) {
        const caps = await this.getUserCapabilities.execute({ userId: input.actorUserId });
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
                  userId: input.actorUserId,
                  attemptedVenueName: nextVenueName,
                  attemptedVenueCategory: nextVenueCategory.value,
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
    }

    const patch: Parameters<Event['edit']>[0] = {};
    if (input.patch.title !== undefined) patch.title = input.patch.title;
    if (input.patch.description !== undefined) patch.description = input.patch.description;
    if (input.patch.venue !== undefined) patch.venue = Venue.create(input.patch.venue);
    if (input.patch.startsAt !== undefined) patch.startsAt = input.patch.startsAt;
    if (input.patch.endsAt !== undefined) patch.endsAt = input.patch.endsAt;
    if (input.patch.capacity !== undefined) patch.capacity = Capacity.create(input.patch.capacity);
    if (input.patch.category !== undefined) {
      patch.category = EventCategory.create(input.patch.category);
    }
    if (input.patch.venueCategory !== undefined) {
      patch.venueCategory = VenueCategory.create(input.patch.venueCategory);
    }
    if (input.patch.costSplit !== undefined) patch.costSplit = input.patch.costSplit;
    if (input.patch.approvalMode !== undefined) patch.approvalMode = input.patch.approvalMode;

    const now = this.clock.now();
    event.edit(patch, now);

    const pending = event.pullEvents();
    if (pending.length === 0) {
      // No-op edit — don't even open a transaction.
      return event;
    }

    await this.unitOfWork.run(async (ctx) => {
      await this.events.save(event, ctx);
      await this.publisher.publish(ctx, ...pending);
    });

    return event;
  }
}
