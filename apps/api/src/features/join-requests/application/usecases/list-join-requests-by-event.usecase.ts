import { AppError } from '@/core/errors/app-error.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { JoinRequest } from '../../domain/entities/join-request.js';
import type { JoinRequestRepository } from '../../domain/repositories/join-request.repository.js';
import type {
  JoinRequestWithRequester,
  ListJoinRequestsByEventResult,
} from '../dto/list-join-requests-by-event.result.js';

export interface ListJoinRequestsByEventInput {
  eventId: string;
  actorUserId: string;
}

/**
 * Visibility-scoped listing of join requests for an event, enriched with
 * requester displayName so the host can render a name without a second fetch.
 *
 * Rules:
 *   - Host → sees every request on their event (with requester info).
 *   - Requester → sees only their own row(s) (requester info is themselves).
 *   - Non-host, non-requester → sees an empty list. NO 403.
 *     Rationale: returning 403 leaks the existence of "you have no join
 *     request for this event" as a different shape from "you do". An empty
 *     200 is privacy-preserving and the simplest client contract.
 *
 * 404 only when the parent Event itself doesn't exist.
 *
 * Users missing from the user repository (admin-deleted accounts) are
 * silently dropped from the result rather than surfacing a 500 — the host
 * should still be able to see the other requesters.
 */
export class ListJoinRequestsByEventUseCase {
  constructor(
    private readonly joinRequests: JoinRequestRepository,
    private readonly events: EventRepository,
    private readonly users: UserRepository,
  ) {}

  async execute(input: ListJoinRequestsByEventInput): Promise<ListJoinRequestsByEventResult> {
    const event = await this.events.findById(input.eventId);
    if (!event) throw AppError.notFound(`Event ${input.eventId} not found`);

    let rows: JoinRequest[];

    if (event.hostUserId === input.actorUserId) {
      rows = await this.joinRequests.findByEvent(input.eventId, {});
    } else {
      rows = await this.joinRequests.findByEvent(input.eventId, {
        requesterUserId: input.actorUserId,
      });
    }

    // Batch-fetch distinct requesters — one query per distinct user id.
    // For the requester-scoped path this is at most one lookup; for the host
    // path it's bounded by event capacity (always small).
    const requesterIds = [...new Set(rows.map((jr) => jr.requesterUserId))];
    const userMap = new Map<string, Awaited<ReturnType<UserRepository['findById']>>>();
    await Promise.all(
      requesterIds.map(async (id) => {
        const user = await this.users.findById(id);
        userMap.set(id, user);
      }),
    );

    const enriched: JoinRequestWithRequester[] = [];
    for (const jr of rows) {
      const requester = userMap.get(jr.requesterUserId);
      if (!requester) continue; // silently drop orphaned rows
      enriched.push({ joinRequest: jr, requester });
    }

    return { joinRequests: enriched };
  }
}
