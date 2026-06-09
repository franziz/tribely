import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/index.js';
import { AppError } from '@/core/errors/app-error.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import type { SafetyReminderMarkerPort } from '../ports/safety-reminder-marker.port.js';

export interface MarkSafetyReminderSeenInput {
  userId: string;
  eventId: string;
}

/**
 * Mark the pre-event safety reminder as seen for the given user and event.
 *
 * The aggregate's `markSafetyReminderSeen` is idempotent — if the reminder
 * was already seen for this event, no state change and no event is recorded.
 * `pullEvents()` returns empty and `publish` is a no-op. Do not special-case
 * the already-seen path here.
 */
export class MarkSafetyReminderSeenUseCase implements SafetyReminderMarkerPort {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: MarkSafetyReminderSeenInput): Promise<void> {
    const user = await this.users.findById(input.userId);
    if (!user) throw AppError.notFound(`User ${input.userId} not found`);

    await this.unitOfWork.run(async (ctx) => {
      user.markSafetyReminderSeen(input.eventId, this.clock.now());
      await this.users.save(user, ctx);
      await this.publisher.publish(ctx, ...user.pullEvents());
    });
  }
}
