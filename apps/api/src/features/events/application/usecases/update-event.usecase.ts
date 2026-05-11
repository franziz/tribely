import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { Event, ApprovalMode, CostSplit } from '../../domain/entities/event.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
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
 */
export class UpdateEventUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly events: EventRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: UpdateEventInput): Promise<Event> {
    const event = await this.events.findById(input.eventId);
    if (!event) throw AppError.notFound(`Event ${input.eventId} not found`);
    if (event.hostUserId !== input.actorUserId) {
      throw AppError.forbidden('Only the host may edit this event');
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
