import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import { AppError } from '@/core/errors/app-error.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { JoinRequestRepository } from '../../domain/repositories/join-request.repository.js';

export interface CancelJoinRequestByRequesterInput {
  joinRequestId: string;
  actorUserId: string;
}

/**
 * Requester cancels their own join request.
 *
 * Allowed from pending OR approved — "I changed my mind" is a real flow even
 * after approval. The aggregate emits `previousStatus` in the event so the
 * notification consumer can distinguish a withdrawn pending request from an
 * approved-then-dropped attendee (the host needs to know about the latter
 * for headcount).
 *
 * Authorization: only the requester themselves. Hosts can't use this path to
 * remove an attendee — that's a separate (future) host.removedAttendee flow.
 */
export class CancelJoinRequestByRequesterUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly joinRequests: JoinRequestRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: CancelJoinRequestByRequesterInput): Promise<void> {
    const jr = await this.joinRequests.findById(input.joinRequestId);
    if (!jr) throw AppError.notFound(`Join request ${input.joinRequestId} not found`);

    if (jr.requesterUserId !== input.actorUserId) {
      throw AppError.forbidden('Only the requester may cancel this join request');
    }

    const now = this.clock.now();

    await this.unitOfWork.run(async (ctx) => {
      jr.cancelByRequester(now);
      await this.joinRequests.save(jr, ctx);
      await this.publisher.publish(ctx, ...jr.pullEvents());
    });
  }
}
