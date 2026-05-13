import type { JoinRequest } from '../../domain/entities/join-request.js';
import type { User } from '@/features/users/domain/entities/user.js';

/**
 * A join request paired with the requester's user record so the host-facing
 * list can render a name alongside each request without a second fetch.
 *
 * `requester` is the full User aggregate; the presentation layer projects
 * whatever fields it needs (currently only `id` + `displayName`).
 */
export interface JoinRequestWithRequester {
  joinRequest: JoinRequest;
  requester: User;
}

/**
 * Result of {@link ListJoinRequestsByEventUseCase.execute}.
 */
export interface ListJoinRequestsByEventResult {
  joinRequests: JoinRequestWithRequester[];
}
