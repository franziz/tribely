import type { UserBlockRepository } from '../../domain/repositories/user-block.repository.js';
import type { CheckBlockedPort } from '../../application/ports/check-blocked.port.js';

/**
 * Concrete implementation of `CheckBlockedPort` that delegates to the
 * `UserBlockRepository`. Block checks are BIDIRECTIONAL in the repo.
 */
export class RepositoryCheckBlockedAdapter implements CheckBlockedPort {
  constructor(private readonly userBlocks: UserBlockRepository) {}

  filterBlocked(input: { viewerId: string; candidateIds: string[] }): Promise<Set<string>> {
    if (input.candidateIds.length === 0) {
      return Promise.resolve(new Set<string>());
    }
    return this.userBlocks.filterBlocked(input);
  }

  async isBlocked(input: { viewerId: string; targetId: string }): Promise<boolean> {
    const block = await this.userBlocks.findBidirectional({
      userA: input.viewerId,
      userB: input.targetId,
    });
    return block !== null;
  }
}
