import type {
  JoinRequestWithEventSummary,
  ListJoinRequestsByRequesterCursor,
} from '../../domain/repositories/join-request.repository.js';

export interface ListJoinRequestsByRequesterResult {
  items: JoinRequestWithEventSummary[];
  nextCursor: ListJoinRequestsByRequesterCursor | null;
}
