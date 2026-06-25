import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/index.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';

export interface ResetSafetyReminderSeenInput {
  userId: string;
}

/**
 * Clear the pre-event safety-reminder seen flag so the TRI-34 safety sheet
 * re-shows on the user's next request-to-join (TRI-270).
 *
 * NOTE: Unlike `MarkSafetyReminderSeenUseCase`, this use case does NOT throw
 * when the user is not found. It is driven by an at-least-once event consumer,
 * not an HTTP request — a missing user (e.g. account deleted between the
 * flagging event and its dispatch) must not poison the consumer offset with a
 * permanent failure. A missing user is silently ignored.
 */
export class ResetSafetyReminderSeenUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: ResetSafetyReminderSeenInput): Promise<void> {
    const user = await this.users.findById(input.userId);
    if (!user) return; // consumer-context: missing user is a no-op, not an error

    await this.unitOfWork.run(async (ctx) => {
      user.clearSafetyReminderSeen('checkInFlagged', this.clock.now());
      await this.users.save(user, ctx);
      await this.publisher.publish(ctx, ...user.pullEvents());
    });
  }
}
