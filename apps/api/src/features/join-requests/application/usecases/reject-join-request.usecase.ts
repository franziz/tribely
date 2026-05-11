import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import { AppError } from '@/core/errors/app-error.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { JoinRequest } from '../../domain/entities/join-request.js';
import type { JoinRequestRepository } from '../../domain/repositories/join-request.repository.js';

export interface RejectJoinRequestInput {
  joinRequestId: string;
  actorUserId: string;
  reason: string;
}

/**
 * Host rejects a pending join request.
 *
 * No row lock on the parent Event — rejection DECREASES load (no capacity
 * concern, no serialization needed). The aggregate validates the reason
 * (1-500 chars, trimmed) and enforces the state transition (pending → rejected
 * only; throws ALREADY_REJECTED on retry).
 */
export class RejectJoinRequestUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly joinRequests: JoinRequestRepository,
    private readonly events: EventRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: RejectJoinRequestInput): Promise<JoinRequest> {
    const jr = await this.joinRequests.findById(input.joinRequestId);
    if (!jr) throw AppError.notFound(`Join request ${input.joinRequestId} not found`);

    const event = await this.events.findById(jr.eventId);
    if (!event) throw AppError.notFound(`Event ${jr.eventId} not found`);

    if (event.hostUserId !== input.actorUserId) {
      throw AppError.forbidden('Only the host may reject this join request');
    }

    const now = this.clock.now();

    await this.unitOfWork.run(async (ctx) => {
      jr.reject({ by: input.actorUserId, reason: input.reason, now });
      await this.joinRequests.save(jr, ctx);
      await this.publisher.publish(ctx, ...jr.pullEvents());
    });

    return jr;
  }
}
