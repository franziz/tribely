import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';

export interface CancelEventInput {
  eventId: string;
  actorUserId: string;
  reason: string | null;
}

const DEFAULT_REASON = 'Cancelled by host';

/**
 * Host-initiated soft delete via DELETE /events/:id. The aggregate refuses to
 * cancel an already-completed event; idempotent on already-cancelled
 * (returns the existing reason).
 */
export class CancelEventUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly events: EventRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: CancelEventInput): Promise<void> {
    const event = await this.events.findById(input.eventId);
    if (!event) throw AppError.notFound(`Event ${input.eventId} not found`);
    if (event.hostUserId !== input.actorUserId) {
      throw AppError.forbidden('Only the host may cancel this event');
    }

    const reason = input.reason && input.reason.trim().length > 0 ? input.reason : DEFAULT_REASON;
    const now = this.clock.now();
    event.cancel(reason, now);

    const pending = event.pullEvents();
    if (pending.length === 0) return; // idempotent re-cancel

    await this.unitOfWork.run(async (ctx) => {
      await this.events.save(event, ctx);
      await this.publisher.publish(ctx, ...pending);
    });
  }
}
