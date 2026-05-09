import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { RefreshTokenHasher } from '../../domain/ports/refresh-token-hasher.port.js';
import type { RefreshTokenRepository } from '../../domain/repositories/refresh-token.repository.js';

export interface SignOutInput {
  refreshTokenPlaintext: string;
}

/**
 * Sign out a single session by revoking the refresh token. Idempotent —
 * no error if the token doesn't exist or is already revoked. Access tokens
 * remain valid until natural expiry (15 min); for instant logout from all
 * devices use SignOutAllUseCase.
 */
export class SignOutUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly refreshHasher: RefreshTokenHasher,
    private readonly events: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: SignOutInput): Promise<void> {
    const hash = this.refreshHasher.hash(input.refreshTokenPlaintext);
    const token = await this.refreshTokens.findByTokenHash(hash);
    if (!token || token.isRevoked()) return;

    const now = this.clock.now();
    token.revoke('signed_out', now);

    await this.unitOfWork.run(async (ctx) => {
      await this.refreshTokens.save(token, ctx);
      await this.events.publish(ctx, ...token.pullEvents());
    });
  }
}
