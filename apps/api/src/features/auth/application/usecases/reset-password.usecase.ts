import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { PasswordHasher } from '../../domain/ports/password-hasher.port.js';
import type { VerificationCodeHasher } from '../../domain/ports/verification-code-hasher.port.js';
import type { CredentialRepository } from '../../domain/repositories/credential.repository.js';
import type { PasswordResetTokenRepository } from '../../domain/repositories/password-reset-token.repository.js';
import { Password } from '../../domain/value-objects/password.js';

export interface ResetPasswordInput {
  email: string;
  code: string;
  newPassword: string;
}

const INVALID_CODE_MESSAGE = 'Invalid or expired reset code.';

/**
 * Completes a password reset.
 *
 * Public, unauthenticated. Atomically (in one transaction):
 *   - Verifies the supplied 6-digit code against the user's open
 *     PasswordResetToken (hash comparison).
 *   - Replaces the password hash on the Credential aggregate.
 *   - Publishes the token-consumed event + the credential `auth.passwordReset`
 *     event.
 *
 * Refresh-token revocation is decoupled: a `signOutAllOnPasswordReset`
 * consumer reacts to `auth.passwordReset` and revokes every active session
 * for the user (reason: `password_reset`). The decoupling means there is a
 * bounded eventual-consistency window between this commit and the consumer
 * firing during which a stolen refresh token can still mint an access token;
 * the window is bounded by the OutboxDispatcher poll interval. This trade-off
 * is deliberate (lets future side-effects fan out from the same event without
 * re-touching this use case) — accept it knowingly when changing the design.
 *
 * Error paths return the SAME generic message ("Invalid or expired reset code")
 * to avoid leaking whether an email exists or whether the code or the password
 * was the problem.
 *
 * Wrong code: increments token.attempts, persists, publishes
 * `auth.passwordResetTokenInvalidated` once the attempts cap is reached, and
 * throws.
 */
export class ResetPasswordUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly credentials: CredentialRepository,
    private readonly tokens: PasswordResetTokenRepository,
    private readonly passwordHasher: PasswordHasher,
    private readonly codeHasher: VerificationCodeHasher,
    private readonly events: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: ResetPasswordInput): Promise<void> {
    // Strength check is up-front: a weak password rejection is fine to surface
    // verbatim because it doesn't leak any user existence information.
    const newPassword = Password.create(input.newPassword);
    const email = Email.create(input.email);
    const newHash = await this.passwordHasher.hash(newPassword);
    const incomingCodeHash = this.codeHasher.hash(input.code);

    const now = this.clock.now();

    await this.unitOfWork.run(async (ctx) => {
      const user = await this.users.findByEmail(email, ctx);
      if (!user) {
        throw AppError.validation(INVALID_CODE_MESSAGE);
      }

      const token = await this.tokens.findOpenByUserId(user.id, ctx);
      if (!token || !token.isOpen(now)) {
        throw AppError.validation(INVALID_CODE_MESSAGE);
      }

      if (token.codeHash !== incomingCodeHash) {
        token.registerFailedAttempt(now);
        await this.tokens.save(token, ctx);
        await this.events.publish(ctx, ...token.pullEvents());
        throw AppError.validation(INVALID_CODE_MESSAGE);
      }

      const credential = await this.credentials.findByUserId(user.id, ctx);
      if (!credential) {
        // No credential for a verified user is a data-integrity failure, not
        // a normal flow. Surface as 500 so it shows up in the error budget.
        throw AppError.internal('Credential not found for user');
      }

      token.consume(now);
      credential.changePassword(newHash, now);

      await this.tokens.save(token, ctx);
      await this.credentials.save(credential, ctx);
      await this.events.publish(ctx, ...token.pullEvents(), ...credential.pullEvents());
    });
  }
}
