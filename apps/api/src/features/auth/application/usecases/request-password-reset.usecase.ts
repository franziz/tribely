import { createId } from '@paralleldrive/cuid2';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EmailSender } from '@/core/email/email-sender.port.js';
import { passwordResetTemplate } from '@/core/email/templates/password-reset.template.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Logger } from '@/core/observability/logger.port.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { PasswordResetToken } from '../../domain/entities/password-reset-token.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { VerificationCodeHasher } from '../../domain/ports/verification-code-hasher.port.js';
import type { PasswordResetTokenRepository } from '../../domain/repositories/password-reset-token.repository.js';

export interface RequestPasswordResetInput {
  email: string;
}

/**
 * Issues a password-reset code for a user, identified by email.
 *
 * Public, unauthenticated endpoint. Two enumeration-safety guards:
 *   - User not found → silent no-op (info-log for ops). Returns success.
 *   - User found but email not verified → silent no-op (info-log for ops).
 *     Returns success. Verified-only gate: an unverified account has a
 *     stronger recovery path (re-verify and continue) and allowing reset on
 *     unverified accounts confirms email existence to attackers.
 *
 * On the happy path:
 *   - Generates a 6-digit code via VerificationCodeHasher.
 *   - Atomically (in a single tx): invalidates any prior open token for the
 *     user (reason='replaced') and saves a fresh one. Both events publish in
 *     the same UnitOfWork so the audit chain is intact.
 *   - Sends the email AFTER commit. If delivery fails the user can re-request;
 *     we don't roll back the persisted token (which would lose the audit
 *     trail of "we tried").
 */
export class RequestPasswordResetUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly tokens: PasswordResetTokenRepository,
    private readonly codeHasher: VerificationCodeHasher,
    private readonly events: EventPublisher,
    private readonly emailSender: EmailSender,
    private readonly clock: Clock,
    private readonly logger: Logger,
    private readonly tokenTtlSeconds: number,
  ) {}

  async execute(input: RequestPasswordResetInput): Promise<void> {
    const email = Email.create(input.email);
    const user = await this.users.findByEmail(email);

    if (!user) {
      this.logger.info(
        { event: 'password_reset.silent_skip', reason: 'user_not_found' },
        'password reset requested for unknown email; silently skipping',
      );
      return;
    }

    if (!user.isEmailVerified()) {
      this.logger.info(
        { event: 'password_reset.silent_skip', reason: 'email_not_verified', userId: user.id },
        'password reset requested for unverified account; silently skipping',
      );
      return;
    }

    const now = this.clock.now();
    const code = this.codeHasher.generate();
    const expiresAt = new Date(now.getTime() + this.tokenTtlSeconds * 1000);

    const newToken = PasswordResetToken.issue({
      id: createId(),
      userId: user.id,
      codeHash: code.hash,
      expiresAt,
      now,
    });

    await this.unitOfWork.run(async (ctx) => {
      const existing = await this.tokens.findOpenByUserId(user.id, ctx);
      if (existing) {
        existing.invalidate('replaced', now);
        await this.tokens.save(existing, ctx);
        await this.events.publish(ctx, ...existing.pullEvents());
      }
      await this.tokens.save(newToken, ctx);
      await this.events.publish(ctx, ...newToken.pullEvents());
    });

    const { subject, html, text } = passwordResetTemplate({ code: code.plaintext });
    await this.emailSender.send({ to: user.email.value, subject, html, text });
  }
}
