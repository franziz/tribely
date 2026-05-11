import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import { AppError } from '@/core/errors/app-error.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { Event } from '@/features/events/domain/entities/event.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { JoinRequest, JoinRequestEventSnapshot } from '../../domain/entities/join-request.js';
import type { JoinRequestRepository } from '../../domain/repositories/join-request.repository.js';

export interface ApproveJoinRequestInput {
  joinRequestId: string;
  actorUserId: string;
}

/**
 * Host approves a pending join request.
 *
 * Runs the read AND the write inside the same UoW, with `findByIdForUpdate`
 * acquiring the row lock on the parent Event before the capacity count. This
 * serializes concurrent approvals targeting the same event so two hosts (or
 * one host clicking twice via two devices) can't both push the headcount
 * past `capacity - 1`.
 *
 * Errors:
 *   - 404 when the JoinRequest doesn't exist.
 *   - 404 when the parent Event is missing (data corruption; defensive — the
 *     FK guarantees this shouldn't happen in practice).
 *   - 403 when the actor isn't the host.
 *   - 409 `CAPACITY_FULL` when approving would exceed `capacity - 1`.
 *   - The aggregate may throw 409 `ALREADY_APPROVED` (or other CONFLICT) for
 *     invalid state transitions; the use case propagates as-is.
 */
export class ApproveJoinRequestUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly joinRequests: JoinRequestRepository,
    private readonly events: EventRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: ApproveJoinRequestInput): Promise<JoinRequest> {
    const now = this.clock.now();

    return this.unitOfWork.run(async (ctx) => {
      const jr = await this.joinRequests.findById(input.joinRequestId, ctx);
      if (!jr) throw AppError.notFound(`Join request ${input.joinRequestId} not found`);

      const event = await this.events.findByIdForUpdate(jr.eventId, ctx);
      if (!event) throw AppError.notFound(`Event ${jr.eventId} not found`);

      if (event.hostUserId !== input.actorUserId) {
        throw AppError.forbidden('Only the host may approve this join request');
      }

      const approvedCount = await this.joinRequests.countApproved(event.id, ctx);
      if (approvedCount >= event.capacity.value - 1) {
        throw AppError.conflict('Event is full', { subcode: 'CAPACITY_FULL' });
      }

      jr.approve({ by: input.actorUserId, now, eventSnapshot: buildSnapshot(event) });
      await this.joinRequests.save(jr, ctx);
      await this.publisher.publish(ctx, ...jr.pullEvents());
      return jr;
    });
  }
}

const buildSnapshot = (event: Event): JoinRequestEventSnapshot => ({
  startsAt: event.startsAt,
  endsAt: event.endsAt,
  venue: {
    address: event.venue.address,
    city: event.venue.city,
    latitude: event.venue.latitude,
    longitude: event.venue.longitude,
  },
  hostUserId: event.hostUserId,
});
