import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { RefreshTokenRepository } from '../../domain/repositories/refresh-token.repository.js';
import type { SignOutAllResult } from '../dto/auth-result.js';

export type SignOutAllReason = 'sign_out_all' | 'password_reset';

export interface SignOutAllInput {
  userId: string;
  /**
   * Why the sign-out is happening. Recorded on every revoked-token event for
   * audit + later metric breakdowns. Defaults to `sign_out_all` (the
   * user-initiated case); the password-reset consumer passes `password_reset`.
   * Other revocation paths (rotated, signed_out single, reuse_detected) flow
   * through their own use cases.
   */
  reason?: SignOutAllReason;
}

/**
 * Sign out every active session for the given user. Used by:
 *   - User-initiated "sign out everywhere" action (reason: 'sign_out_all').
 *   - The `signOutAllOnPasswordReset` consumer reacting to `auth.passwordReset`
 *     (reason: 'password_reset').
 *   - NOT used for reuse-detection — that path is handled inline in
 *     RefreshTokensUseCase to keep the rotation chain atomic.
 *
 * Idempotent: if no active tokens exist, returns `revokedCount: 0` and
 * publishes nothing. Safe under at-least-once consumer redelivery.
 */
export class SignOutAllUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly events: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: SignOutAllInput): Promise<SignOutAllResult> {
    const now = this.clock.now();
    const reason: SignOutAllReason = input.reason ?? 'sign_out_all';

    let revokedCount = 0;
    await this.unitOfWork.run(async (ctx) => {
      const revoked = await this.refreshTokens.revokeAllActiveForUser(
        input.userId,
        reason,
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
