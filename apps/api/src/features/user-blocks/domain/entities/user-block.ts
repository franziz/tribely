import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { AppError } from '@/core/errors/app-error.js';
import { userBlocked } from '../events/user-blocked.event.js';
import { userUnblocked } from '../events/user-unblocked.event.js';

/**
 * Aggregate root for a block relationship between two users.
 *
 * A block is directional: `initiatorUserId` chose to block `blockedUserId`.
 * However, block visibility checks are BIDIRECTIONAL — if A blocks B, neither
 * can see the other's content (enforced by the repository's `findBidirectional`
 * / `filterBlocked` methods).
 *
 * Invariants:
 *   - Self-block is rejected with domain error `CannotBlockSelf`.
 *   - A block is created via `UserBlock.initiate(...)` (factory method).
 *   - An unblock is performed by calling `initiateUnblock()` which records
 *     the `userUnblocked` event; the use case then deletes the row via
 *     `repo.delete(...)` after pulling events.
 */
export class UserBlock extends AggregateRoot {
  private constructor(
    public readonly id: string,
    public readonly initiatorUserId: string,
    public readonly blockedUserId: string,
    public readonly createdAt: Date,
  ) {
    super();
  }

  /**
   * Create a new block relationship and record the `userBlocked` domain event.
   *
   * @throws AppError.unprocessable('CannotBlockSelf') when initiator === blocked.
   */
  static initiate(input: {
    id: string;
    initiatorUserId: string;
    blockedUserId: string;
    now: Date;
  }): UserBlock {
    if (input.initiatorUserId === input.blockedUserId) {
      throw AppError.unprocessable('Cannot block yourself', { subcode: 'CannotBlockSelf' });
    }

    const block = new UserBlock(input.id, input.initiatorUserId, input.blockedUserId, input.now);

    block.record(
      userBlocked({
        id: input.id,
        initiatorUserId: input.initiatorUserId,
        blockedUserId: input.blockedUserId,
        createdAt: input.now.toISOString(),
      }),
    );

    return block;
  }

  /**
   * Rehydrate a UserBlock aggregate from a DB row (no events recorded).
   */
  static rehydrate(state: {
    id: string;
    initiatorUserId: string;
    blockedUserId: string;
    createdAt: Date;
  }): UserBlock {
    return new UserBlock(state.id, state.initiatorUserId, state.blockedUserId, state.createdAt);
  }

  /**
   * Record the `userUnblocked` event. The caller (use case) is responsible for
   * deleting the row via `repo.delete(...)` after pulling events.
   */
  initiateUnblock(now: Date): void {
    this.record(
      userUnblocked({
        id: this.id,
        initiatorUserId: this.initiatorUserId,
        blockedUserId: this.blockedUserId,
        unblockedAt: now.toISOString(),
      }),
    );
  }
}
