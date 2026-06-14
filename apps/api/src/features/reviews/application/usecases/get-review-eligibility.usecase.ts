import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { JoinRequestRepository } from '@/features/join-requests/domain/repositories/join-request.repository.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { ReviewEligibilityDto } from '../dto/review-eligibility.dto.js';
import type { ReviewRepository } from '../../domain/repositories/review.repository.js';

export interface GetReviewEligibilityInput {
  /** The authenticated viewer checking their own eligibility. */
  viewerId: string;
  eventId: string;
}

const DAYS_7_MS = 7 * 24 * 60 * 60 * 1000;
const HOURS_24_MS = 24 * 60 * 60 * 1000;

const INELIGIBLE: ReviewEligibilityDto = {
  eligible: false,
  ratedUserId: null,
  hostDisplayName: null,
};

/**
 * Returns whether the authenticated viewer may write an attendee→host review
 * for the given event.
 *
 * Predicate order (mirrors ListPendingReviewPromptsUseCase exactly):
 *  1. Event must exist AND status === 'completed'.
 *  2. Viewer must NOT be the host (attendee→host direction only).
 *  3. Viewer must have an approved join request for the event.
 *  4. Viewer must not have already reviewed the host for this event.
 *  5. Event endsAt must be within the 24h–7d window:
 *       now - 7d <= endsAt < now - 24h
 *
 * All failing predicates return `{ eligible: false, ratedUserId: null,
 * hostDisplayName: null }` — no error is thrown. This is intentional: the
 * caller renders a "review" CTA only when eligible; ineligible is a valid
 * non-error state.
 */
export class GetReviewEligibilityUseCase {
  constructor(
    private readonly events: EventRepository,
    private readonly joinRequests: JoinRequestRepository,
    private readonly reviews: ReviewRepository,
    private readonly users: UserRepository,
    private readonly clock: Clock,
  ) {}

  async execute(input: GetReviewEligibilityInput): Promise<ReviewEligibilityDto> {
    const event = await this.events.findById(input.eventId);

    // Predicate 1: event must exist and be completed.
    if (!event || event.status !== 'completed') {
      return INELIGIBLE;
    }

    // Predicate 2: viewer must not be the host (attendee→host only).
    if (event.hostUserId === input.viewerId) {
      return INELIGIBLE;
    }

    // Predicate 3: viewer must have an approved join request.
    const approvedRequests = await this.joinRequests.findByEvent(input.eventId, {
      requesterUserId: input.viewerId,
      status: ['approved'],
    });
    if (approvedRequests.length === 0) {
      return INELIGIBLE;
    }

    // Predicate 4: viewer must not have already reviewed the host.
    const alreadyReviewed = await this.reviews.findExistingTriples({
      raterUserId: input.viewerId,
      pairs: [{ eventId: input.eventId, ratedUserId: event.hostUserId }],
    });
    if (alreadyReviewed.has(`${input.eventId}:${event.hostUserId}`)) {
      return INELIGIBLE;
    }

    // Predicate 5: endsAt within window (now - 7d <= endsAt < now - 24h).
    const now = this.clock.now();
    const completedBefore = new Date(now.getTime() - HOURS_24_MS);
    const completedAfter = new Date(now.getTime() - DAYS_7_MS);

    if (event.endsAt >= completedBefore || event.endsAt < completedAfter) {
      return INELIGIBLE;
    }

    // Eligible — resolve host display name.
    const host = await this.users.findById(event.hostUserId);

    return {
      eligible: true,
      ratedUserId: event.hostUserId,
      hostDisplayName: host?.displayName.value ?? null,
    };
  }
}
