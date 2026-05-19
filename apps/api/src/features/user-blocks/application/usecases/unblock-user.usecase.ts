import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { UserBlockRepository } from '../../domain/repositories/user-block.repository.js';

export interface UnblockUserInput {
  initiatorUserId: string;
  blockedUserId: string;
}

/**
 * Unblock a user.
 *
 * Idempotency: if no block exists for (initiatorUserId, blockedUserId), this
 * is a silent no-op — returns without error or event emission.
 *
 * On a successful unblock:
 *   1. Loads the existing block.
 *   2. Records `userUnblocked` event on the aggregate.
 *   3. Publishes the event.
 *   4. Deletes the row via `repo.delete(...)`.
 *
 * All operations are atomic within `UnitOfWork.run(...)`.
 *
 * Per CEO Condition 3: cancelled join-requests are NOT restored on unblock.
 */
export class UnblockUserUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly userBlocks: UserBlockRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: UnblockUserInput): Promise<void> {
    const existing = await this.userBlocks.findOne({
      initiatorUserId: input.initiatorUserId,
      blockedUserId: input.blockedUserId,
    });

    // Idempotent on not-blocked.
    if (!existing) return;

    const now = this.clock.now();
    existing.initiateUnblock(now);

    await this.unitOfWork.run(async (ctx) => {
      await this.publisher.publish(ctx, ...existing.pullEvents());
      await this.userBlocks.delete(
        { initiatorUserId: input.initiatorUserId, blockedUserId: input.blockedUserId },
        ctx,
      );
    });
  }
}
