import type { HostRatingsReadModel } from '../../domain/ports/host-ratings-read-model.port.js';

/**
 * STUB: returns null for every host. Replaced when the host-rating system
 * ships — tracked in TRI-92 (Activate private-venue unlock once host-rating
 * average is computable). Until then, the TRI-33 capability gate resolves
 * `canPostPrivateVenue: false` for every host by CEO Path A ruling.
 */
export class StubHostRatingsReadModel implements HostRatingsReadModel {
  getAverageRatingForHost(_hostUserId: string): Promise<number | null> {
    return Promise.resolve(null);
  }
}
