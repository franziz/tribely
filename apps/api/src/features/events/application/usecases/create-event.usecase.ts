import { createId } from '@paralleldrive/cuid2';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import { Event, type ApprovalMode, type CostSplit } from '../../domain/entities/event.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
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
  costSplit: CostSplit;
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
 */
export class CreateEventUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly events: EventRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: CreateEventInput): Promise<Event> {
    const venue = Venue.create(input.venue);
    const capacity = Capacity.create(input.capacity);
    const category = EventCategory.create(input.category);
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
      costSplit: input.costSplit,
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
