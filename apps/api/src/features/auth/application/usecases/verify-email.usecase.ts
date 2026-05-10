import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { VerificationCodeHasher } from '../../domain/ports/verification-code-hasher.port.js';
import type { EmailVerificationTokenRepository } from '../../domain/repositories/email-verification-token.repository.js';

export interface VerifyEmailInput {
  userId: string;
  code: string;
}

export interface VerifyEmailResult {
  user: User;
}

/**
 * Verifies a user's email by checking a 6-digit code against their open
 * verification token.
 *
 * - User already verified: idempotent success (returns user). Lets the mobile
 *   client poll the same endpoint without surfacing spurious errors.
 * - No open token / expired / invalidated: 400. The user should resend.
 * - Code mismatch: 400, increments the token's `attempts`. After 5 wrong
 *   submissions the token self-invalidates (forces a resend; defeats brute
 *   force given the 1M code space).
 *
 * On success, marks `User.emailVerifiedAt` and consumes the token in the
 * same transaction; events from both aggregates are published atomically.
 */
export class VerifyEmailUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly tokens: EmailVerificationTokenRepository,
    private readonly codeHasher: VerificationCodeHasher,
    private readonly events: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: VerifyEmailInput): Promise<VerifyEmailResult> {
    const now = this.clock.now();
    const incomingHash = this.codeHasher.hash(input.code);

    return this.unitOfWork.run(async (ctx) => {
      const user = await this.users.findById(input.userId, ctx);
      if (!user) throw AppError.notFound('User not found');
      if (user.isEmailVerified()) return { user };

      const token = await this.tokens.findOpenByUserId(user.id, ctx);
      if (!token || !token.isOpen(now)) {
        throw AppError.validation('No active verification code. Request a new one.');
      }

      if (token.codeHash !== incomingHash) {
        token.registerFailedAttempt(now);
        await this.tokens.save(token, ctx);
        await this.events.publish(ctx, ...token.pullEvents());
        throw AppError.validation('Invalid verification code.');
      }

      token.consume(now);
      user.verifyEmail(now);

      await this.tokens.save(token, ctx);
      await this.users.save(user, ctx);
      await this.events.publish(ctx, ...token.pullEvents(), ...user.pullEvents());

      return { user };
    });
  }
}
