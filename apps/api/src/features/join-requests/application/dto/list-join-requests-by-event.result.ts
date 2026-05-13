import type { JoinRequestWithRequester } from '../../domain/repositories/join-request.repository.js';

export interface ListJoinRequestsByEventResult {
  joinRequests: JoinRequestWithRequester[];
}
