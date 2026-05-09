import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { RefreshToken } from '../../domain/entities/refresh-token.js';
import type { AccessTokenIssuer } from '../../domain/ports/access-token-issuer.port.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { RefreshTokenHasher } from '../../domain/ports/refresh-token-hasher.port.js';
import type { RefreshTokenRepository } from '../../domain/repositories/refresh-token.repository.js';
import type { IssuedAuthSession } from '../dto/auth-result.js';

export interface RefreshTokensInput {
  refreshTokenPlaintext: string;
  deviceLabel?: string | null;
}

/**
 * Refresh token rotation:
 *
 * 1. Hash the provided plaintext, look up the row.
 * 2. If not found → 401 (could be wrong, expired-and-cleaned, or fabricated).
 * 3. If found and revokedAt is set → REUSE. Treat as theft. Revoke ALL of the
 *    user's active refresh tokens, publish reuse-detected event, return 401.
 * 4. If found and expired → 401.
 * 5. Otherwise: rotate. The presented token is marked revoked (reason='rotated'),
 *    a fresh RefreshToken is issued with rotatedToId set on the old. Issue a
 *    new access JWT. All writes + events committed in one UnitOfWork.
 */
export class RefreshTokensUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly accessTokens: AccessTokenIssuer,
    private readonly refreshHasher: RefreshTokenHasher,
    private readonly events: EventPublisher,
    private readonly clock: Clock,
    private readonly refreshTokenTtlSeconds: number,
  ) {}

  async execute(input: RefreshTokensInput): Promise<IssuedAuthSession> {
    const presentedHash = this.refreshHasher.hash(input.refreshTokenPlaintext);
    const presented = await this.refreshTokens.findByTokenHash(presentedHash);
    const now = this.clock.now();

    if (!presented) throw AppError.unauthorized('Invalid refresh token');

    // Reuse detection: a previously revoked token has shown up again.
    if (presented.isRevoked()) {
      presented.markReuseDetected(now);
      await this.unitOfWork.run(async (ctx) => {
        const revoked = await this.refreshTokens.revokeAllActiveForUser(
          presented.userId,
          'reuse_detected',
          now,
          ctx,
        );
        await this.events.publish(
          ctx,
          ...presented.pullEvents(),
          ...revoked.flatMap((t) => t.pullEvents()),
        );
      });
      throw AppError.unauthorized('Refresh token reuse detected');
    }

    if (presented.isExpired(now)) throw AppError.unauthorized('Refresh token expired');

    const user = await this.users.findById(presented.userId);
    if (!user) throw AppError.unauthorized('User no longer exists');

    const refreshExpiresAt = new Date(now.getTime() + this.refreshTokenTtlSeconds * 1000);
    const newSecret = this.refreshHasher.generate();
    const newId = createId();
    const newToken = RefreshToken.issue({
      id: newId,
      userId: presented.userId,
      tokenHash: newSecret.hash,
      expiresAt: refreshExpiresAt,
      deviceLabel: input.deviceLabel ?? presented.deviceLabel,
      now,
    });
    presented.rotate(newId, now);

    await this.unitOfWork.run(async (ctx) => {
      await this.refreshTokens.save(presented, ctx);
      await this.refreshTokens.save(newToken, ctx);
      await this.events.publish(
        ctx,
        ...presented.pullEvents(),
        ...newToken.pullEvents(),
      );
    });

    const accessToken = await this.accessTokens.issue({ userId: user.id, email: user.email.value });

    return {
      user,
      accessToken,
      refreshTokenPlaintext: newSecret.plaintext,
      refreshTokenExpiresAt: refreshExpiresAt,
    };
  }
}
