import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import { AppError } from '@/core/errors/app-error.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { JoinRequest } from '../../domain/entities/join-request.js';
import type { JoinRequestRepository } from '../../domain/repositories/join-request.repository.js';

export interface RemoveJoinRequestByHostInput {
  joinRequestId: string;
  actorUserId: string;
  reason: string;
}

/**
 * Host removes an approved attendee from the event.
 *
 * Uses `findByIdForUpdate` on the parent Event to acquire a row lock — the
 * same serialization pattern as `ApproveJoinRequestUseCase`. Although
 * `removeByHost` doesn't affect capacity reads directly, locking serializes
 * concurrent host actions against the same event (e.g., simultaneous remove +
 * approve targeting different attendees) and keeps the use-case patterns
 * consistent.
 *
 * Errors:
 *   - 404 when the JoinRequest doesn't exist.
 *   - 404 when the parent Event is missing (data corruption; defensive).
 *   - 403 when the actor isn't the host.
 *   - 409 `ALREADY_REMOVED_BY_HOST` on idempotent retry.
 *   - 409 (generic) when the JR is in a non-approved terminal state — the
 *     aggregate message includes the current status name.
 *   - 422 when `reason` fails validation (empty or >200 chars after trim).
 */
export class RemoveJoinRequestByHostUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly joinRequests: JoinRequestRepository,
    private readonly events: EventRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: RemoveJoinRequestByHostInput): Promise<JoinRequest> {
    const now = this.clock.now();

    return this.unitOfWork.run(async (ctx) => {
      const jr = await this.joinRequests.findById(input.joinRequestId, ctx);
      if (!jr) throw AppError.notFound(`Join request ${input.joinRequestId} not found`);

      const event = await this.events.findByIdForUpdate(jr.eventId, ctx);
      if (!event) throw AppError.notFound(`Event ${jr.eventId} not found`);

      if (event.hostUserId !== input.actorUserId) {
        throw AppError.forbidden('Only the host may remove this attendee');
      }

      jr.removeByHost({
        by: input.actorUserId,
        hostUserId: event.hostUserId,
        reason: input.reason,
        now,
      });

      await this.joinRequests.save(jr, ctx);
      await this.publisher.publish(ctx, ...jr.pullEvents());
      return jr;
    });
  }
}
