import { AppError } from '@/core/errors/app-error.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import {
  computeIsVerified,
  type VerificationSignalId,
} from '@/features/users/application/projections/is-verified.projection.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';
import type { EventWithHost } from '../dto/event-with-host.js';

export interface GetEventInput {
  id: string;
}

/**
 * Fetch a single Event by id and bundle the host's public projection.
 *
 * Public endpoint (no auth) — only exposes the host's id + displayName +
 * derived `isVerified` so email / verification timestamps stay out of the
 * response. `isVerified` is sourced from the canonical TRI-86 projection.
 */
export class GetEventUseCase {
  constructor(
    private readonly events: EventRepository,
    private readonly users: UserRepository,
    private readonly signalSet: VerificationSignalId[],
  ) {}

  async execute(input: GetEventInput): Promise<EventWithHost> {
    const event = await this.events.findById(input.id);
    if (!event) throw AppError.notFound(`Event ${input.id} not found`);
    const host = await this.users.findById(event.hostUserId);
    if (!host) {
      throw AppError.internal(`Event ${event.id} references missing host ${event.hostUserId}`);
    }

    const isVerified = computeIsVerified(
      {
        emailVerifiedAt: host.emailVerifiedAt,
        // TODO(TRI-16): replace with host.phoneVerifiedAt once phone column lands
        phoneVerifiedAt: null,
        // TODO(TRI-23): replace with host.selfieApprovedAt once selfie column lands
        selfieApprovedAt: null,
      },
      this.signalSet,
    );

    return {
      event,
      host: { id: host.id, displayName: host.displayName.value, isVerified },
    };
  }
}
