import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { HostRatingsReadModel } from '../../domain/ports/host-ratings-read-model.port.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import { computeCanPerformVerifiedAction } from '../projections/can-perform-verified-action.projection.js';
import type { UserCapabilitiesResult } from '../dto/user-capabilities-result.dto.js';
import { AppError } from '@/core/errors/app-error.js';

/**
 * Determines what privileged actions the given user is currently authorized to
 * perform.
 *
 * canPostPrivateVenue (TRI-33): permanently false at MVP launch (CEO Path A
 * ruling) — a host must have at least one completed event AND a ratings
 * average ≥ 4.0; the stub adapter (TRI-92) returns null for every host until
 * the rating system ships.
 *
 * canPerformVerifiedAction (TRI-70): real-time gate derived from the user's
 * current selfie state. True only when selfieStatus === 'approved' AND
 * selfieAppealLockedAt === null.
 */
export class GetUserCapabilitiesUseCase {
  constructor(
    private readonly eventRepo: EventRepository,
    private readonly hostRatings: HostRatingsReadModel,
    private readonly users: UserRepository,
  ) {}

  async execute(input: { userId: string }): Promise<UserCapabilitiesResult> {
    const [completedCount, user] = await Promise.all([
      this.eventRepo.countCompletedByHost(input.userId),
      this.users.findById(input.userId),
    ]);

    if (!user) throw AppError.notFound(`User ${input.userId} not found`);

    const canPerformVerifiedAction = computeCanPerformVerifiedAction({
      selfieStatus: user.selfieStatus,
      selfieAppealLockedAt: user.selfieAppealLockedAt,
    });

    const safetyReminderSeen = user.safetyReminderSeenAt !== null;

    if (completedCount === 0)
      return { canPostPrivateVenue: false, canPerformVerifiedAction, safetyReminderSeen };

    const avgRating = await this.hostRatings.getAverageRatingForHost(input.userId);
    return {
      canPostPrivateVenue: avgRating !== null && avgRating >= 4.0,
      canPerformVerifiedAction,
      safetyReminderSeen,
    };
  }
}
