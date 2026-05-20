import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { JoinRequestRepository } from '@/features/join-requests/domain/repositories/join-request.repository.js';
import type { ReviewRepository } from '@/features/reviews/domain/repositories/review.repository.js';
import type { CheckBlockedPort } from '@/features/user-blocks/application/ports/check-blocked.port.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import type { ListPendingReviewPromptsResult } from '../dto/list-pending-review-prompts.dto.js';

export interface ListPendingReviewPromptsInput {
  /** ID of the authenticated user requesting their pending review prompt. */
  viewerId: string;
}

const DAYS_7_MS = 7 * 24 * 60 * 60 * 1000;
const HOURS_24_MS = 24 * 60 * 60 * 1000;

/**
 * Returns the single oldest unreviewed counterpart from the viewer's completed
 * events within the review window (ended > 24h ago, ended <= 7d ago).
 *
 * Algorithm:
 *  1. Find completed events where viewer was host or approved joiner, within window.
 *  2. For each event, derive candidate counterparts:
 *       - If viewer is host: all approved joiners.
 *       - If viewer is joiner: just the host.
 *  3. Exclude pairs already reviewed by viewer (batched lookup).
 *  4. Exclude blocked counterparts (bidirectional, batched).
 *  5. Sort remaining pairs by event.endsAt ASC, then counterpartId ASC (deterministic).
 *  6. Return the first pair's prompt (or null if none remain).
 *
 * Performance: 1 query for events + 1 for approved joiners + 1 batched review
 * lookup + 1 batched block-check + 1 user lookup for the chosen prompt.
 */
export class ListPendingReviewPromptsUseCase {
  constructor(
    private readonly eventRepo: EventRepository,
    private readonly joinRequestRepo: JoinRequestRepository,
    private readonly reviewRepo: ReviewRepository,
    private readonly checkBlocked: CheckBlockedPort,
    private readonly userRepo: UserRepository,
    private readonly clock: Clock,
  ) {}

  async execute(input: ListPendingReviewPromptsInput): Promise<ListPendingReviewPromptsResult> {
    const now = this.clock.now();
    const completedBefore = new Date(now.getTime() - HOURS_24_MS);
    const completedAfter = new Date(now.getTime() - DAYS_7_MS);

    // Step 1: find all completed events where viewer was involved.
    const events = await this.eventRepo.findCompletedForUserBetween({
      userId: input.viewerId,
      completedAfter,
      completedBefore,
    });

    if (events.length === 0) return { prompt: null };

    // Step 2: build candidate (eventId, counterpartId) pairs.
    // Separate events where viewer is host from events where viewer is joiner
    // so we can batch the approved-joiner lookup for host events.
    const hostEventIds: string[] = [];
    const joinerPairs: Array<{ eventId: string; counterpartId: string; endsAt: Date }> = [];

    for (const event of events) {
      if (event.hostUserId === input.viewerId) {
        hostEventIds.push(event.id);
      } else {
        joinerPairs.push({
          eventId: event.id,
          counterpartId: event.hostUserId,
          endsAt: event.endsAt,
        });
      }
    }

    // Batch-fetch approved joiners for all host events in a single query.
    const approvedRequests =
      hostEventIds.length > 0 ? await this.joinRequestRepo.listApprovedByEvents(hostEventIds) : [];

    // Build an endsAt map for the host events (needed for sorting).
    const endsAtByEventId = new Map(events.map((e) => [e.id, e.endsAt]));

    // Flatten host-event candidates.
    const hostPairs: Array<{ eventId: string; counterpartId: string; endsAt: Date }> =
      approvedRequests.map((jr) => ({
        eventId: jr.eventId,
        counterpartId: jr.requesterUserId,
        endsAt: endsAtByEventId.get(jr.eventId) ?? new Date(0),
      }));

    const allCandidates = [...hostPairs, ...joinerPairs];

    if (allCandidates.length === 0) return { prompt: null };

    // Step 3: exclude already-reviewed pairs (batched).
    const pairsForLookup = allCandidates.map((c) => ({
      eventId: c.eventId,
      ratedUserId: c.counterpartId,
    }));
    const alreadyReviewed = await this.reviewRepo.findExistingTriples({
      raterUserId: input.viewerId,
      pairs: pairsForLookup,
    });

    const unreviewed = allCandidates.filter(
      (c) => !alreadyReviewed.has(`${c.eventId}:${c.counterpartId}`),
    );

    if (unreviewed.length === 0) return { prompt: null };

    // Step 4: exclude blocked counterparts (bidirectional, batched).
    const distinctCounterpartIds = [...new Set(unreviewed.map((c) => c.counterpartId))];
    const blockedSet = await this.checkBlocked.filterBlocked({
      viewerId: input.viewerId,
      candidateIds: distinctCounterpartIds,
    });

    const eligible = unreviewed.filter((c) => !blockedSet.has(c.counterpartId));

    if (eligible.length === 0) return { prompt: null };

    // Step 5: sort by endsAt ASC, then counterpartId ASC for determinism.
    eligible.sort((a, b) => {
      const timeDiff = a.endsAt.getTime() - b.endsAt.getTime();
      if (timeDiff !== 0) return timeDiff;
      return a.counterpartId < b.counterpartId ? -1 : a.counterpartId > b.counterpartId ? 1 : 0;
    });

    // Step 6: pick the first and resolve display fields.
    const chosen = eligible[0];
    // eligible is guaranteed non-empty here; the check above returns early if empty.
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const { eventId, counterpartId, endsAt } = chosen!;

    const event = events.find((e) => e.id === eventId);
    const counterpart = await this.userRepo.findById(counterpartId);

    if (!event || !counterpart) return { prompt: null };

    return {
      prompt: {
        eventId,
        eventTitle: event.title,
        eventEndedAt: endsAt.toISOString(),
        ratedUserId: counterpartId,
        ratedUserDisplayName: counterpart.displayName.value,
        ratedUserAvatarUrl: counterpart.avatarUrl?.value ?? null,
      },
    };
  }
}
