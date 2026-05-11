import { AppError } from '@/core/errors/app-error.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { JoinRequest } from '../../domain/entities/join-request.js';
import type { JoinRequestRepository } from '../../domain/repositories/join-request.repository.js';

export interface ListJoinRequestsByEventInput {
  eventId: string;
  actorUserId: string;
}

export interface ListJoinRequestsByEventResult {
  joinRequests: JoinRequest[];
}

/**
 * Visibility-scoped listing of join requests for an event.
 *
 * Rules:
 *   - Host → sees every request on their event.
 *   - Requester → sees only their own row(s).
 *   - Non-host, non-requester → sees an empty list. NO 403.
 *     Rationale: returning 403 leaks the existence of "you have no join
 *     request for this event" as a different shape from "you do". An empty
 *     200 is privacy-preserving and the simplest client contract.
 *
 * 404 only when the parent Event itself doesn't exist.
 */
export class ListJoinRequestsByEventUseCase {
  constructor(
    private readonly joinRequests: JoinRequestRepository,
    private readonly events: EventRepository,
  ) {}

  async execute(input: ListJoinRequestsByEventInput): Promise<ListJoinRequestsByEventResult> {
    const event = await this.events.findById(input.eventId);
    if (!event) throw AppError.notFound(`Event ${input.eventId} not found`);

    if (event.hostUserId === input.actorUserId) {
      const all = await this.joinRequests.findByEvent(input.eventId, {});
      return { joinRequests: all };
    }

    const mine = await this.joinRequests.findByEvent(input.eventId, {
      requesterUserId: input.actorUserId,
    });
    return { joinRequests: mine };
  }
}
