import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { HostRatingsReadModel } from '../../domain/ports/host-ratings-read-model.port.js';
import type { UserCapabilitiesResult } from '../dto/user-capabilities-result.dto.js';

/**
 * Determines what privileged actions the given user is currently authorized to
 * perform. At MVP launch, `canPostPrivateVenue` is permanently false for every
 * host (CEO Path A ruling, TRI-33): a host must have at least one completed
 * event AND a ratings average ≥ 4.0 — the stub adapter (TRI-92) returns null
 * for every host until the rating system ships.
 */
export class GetUserCapabilitiesUseCase {
  constructor(
    private readonly eventRepo: EventRepository,
    private readonly hostRatings: HostRatingsReadModel,
  ) {}

  async execute(input: { userId: string }): Promise<UserCapabilitiesResult> {
    const completedCount = await this.eventRepo.countCompletedByHost(input.userId);
    if (completedCount === 0) return { canPostPrivateVenue: false };

    const avgRating = await this.hostRatings.getAverageRatingForHost(input.userId);
    return { canPostPrivateVenue: avgRating !== null && avgRating >= 4.0 };
  }
}
