import { createId } from '@paralleldrive/cuid2';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { CascadePendingBlocksPort } from '@/features/join-requests/application/ports/cascade-pending-blocks.port.js';
import { UserBlock } from '../../domain/entities/user-block.js';
import type { UserBlockRepository } from '../../domain/repositories/user-block.repository.js';

export interface BlockUserInput {
  initiatorUserId: string;
  blockedUserId: string;
}

/**
 * Block a user.
 *
 * Idempotency: if a block already exists with the same (initiatorUserId,
 * blockedUserId), return the existing block silently without emitting a
 * second `userBlocked` event or cascading join-requests again.
 *
 * On a new block:
 *   1. Creates and saves the UserBlock aggregate.
 *   2. Publishes `userBlocked` event.
 *   3. Cascades (cancels) pending and future-accepted join requests between
 *      the two users in either direction via `CascadePendingBlocksPort`.
 *
 * All three operations are atomic within the same `UnitOfWork.run(...)`.
 *
 * Note: self-block is rejected by `UserBlock.initiate` (throws 422).
 */
export class BlockUserUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly userBlocks: UserBlockRepository,
    private readonly cascade: CascadePendingBlocksPort,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: BlockUserInput): Promise<UserBlock> {
    // Validate at domain level (self-block throws before any DB access).
    // Build the block outside the transaction to front-load validation.
    const now = this.clock.now();
    const id = createId();
    const block = UserBlock.initiate({
      id,
      initiatorUserId: input.initiatorUserId,
      blockedUserId: input.blockedUserId,
      now,
    });

    // Check idempotency outside transaction for the fast path.
    const existing = await this.userBlocks.findOne({
      initiatorUserId: input.initiatorUserId,
      blockedUserId: input.blockedUserId,
    });
    if (existing) {
      // Pull (and discard) the events we recorded on the new aggregate so the
      // buffer is clean. Return the existing block without re-emitting events.
      block.pullEvents();
      return existing;
    }

    await this.unitOfWork.run(async (ctx) => {
      await this.userBlocks.save(block, ctx);
      await this.publisher.publish(ctx, ...block.pullEvents());
      await this.cascade.cancelPendingAndFutureAcceptedBetween(
        { userA: input.initiatorUserId, userB: input.blockedUserId },
        ctx,
      );
    });

    return block;
  }
}
