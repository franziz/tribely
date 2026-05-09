import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { RefreshTokenRepository } from '../../domain/repositories/refresh-token.repository.js';

export interface SignOutAllInput {
  userId: string;
}

/**
 * Sign out every active session for the given user. Used by:
 *   - User-initiated "sign out everywhere" action.
 *   - Password change / compromise response.
 *   - Triggered by reuse-detection (handled in RefreshTokensUseCase directly,
 *     not via this use case).
 */
export class SignOutAllUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly events: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: SignOutAllInput): Promise<{ revokedCount: number }> {
    const now = this.clock.now();

    let revokedCount = 0;
    await this.unitOfWork.run(async (ctx) => {
      const revoked = await this.refreshTokens.revokeAllActiveForUser(
        input.userId,
        'sign_out_all',
        now,
        ctx,
      );
      revokedCount = revoked.length;
      if (revoked.length === 0) return;
      await this.events.publish(ctx, ...revoked.flatMap((t) => t.pullEvents()));
    });

    return { revokedCount };
  }
}
