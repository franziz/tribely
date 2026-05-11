import { AppError } from '@/core/errors/app-error.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';
import type { EventWithHost } from '../dto/event-with-host.js';

export interface GetEventInput {
  id: string;
}

/**
 * Fetch a single Event by id and bundle the host's public projection.
 *
 * Public endpoint (no auth) — only exposes the host's id + displayName so
 * email / verification timestamps stay out of the response.
 */
export class GetEventUseCase {
  constructor(
    private readonly events: EventRepository,
    private readonly users: UserRepository,
  ) {}

  async execute(input: GetEventInput): Promise<EventWithHost> {
    const event = await this.events.findById(input.id);
    if (!event) throw AppError.notFound(`Event ${input.id} not found`);
    const host = await this.users.findById(event.hostUserId);
    if (!host) {
      throw AppError.internal(`Event ${event.id} references missing host ${event.hostUserId}`);
    }
    return {
      event,
      host: { id: host.id, displayName: host.displayName.value },
    };
  }
}
