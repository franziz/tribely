import type { JoinRequest } from '../../domain/entities/join-request.js';

/**
 * Result of {@link ListJoinRequestsByEventUseCase.execute}.
 */
export interface ListJoinRequestsByEventResult {
  joinRequests: JoinRequest[];
}
