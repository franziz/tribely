import { createId } from '@paralleldrive/cuid2';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EmailSender } from '@/core/email/email-sender.port.js';
import { verificationTemplate } from '@/core/email/templates/verification.template.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { EmailVerificationToken } from '../../domain/entities/email-verification-token.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { VerificationCodeHasher } from '../../domain/ports/verification-code-hasher.port.js';
import type { EmailVerificationTokenRepository } from '../../domain/repositories/email-verification-token.repository.js';

export interface IssueEmailVerificationInput {
  userId: string;
}

/**
 * Issues a fresh email verification token for a user.
 *
 * Used in two places:
 *   1. Subscribed to `users.userRegistered` — fires after sign-up succeeds.
 *      The transactional outbox guarantees at-least-once, so this use case
 *      must be idempotent (and is: an existing open token for the user is
 *      invalidated with reason='replaced' before a new one is issued).
 *   2. Called directly by `ResendVerificationUseCase` for the
 *      `POST /auth/resend-verification` endpoint.
 *
 * No-op when the user is already verified — guards against pointless email
 * sends if a stale event fires after manual verification by ops, etc.
 */
export class IssueEmailVerificationUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly tokens: EmailVerificationTokenRepository,
    private readonly codeHasher: VerificationCodeHasher,
    private readonly events: EventPublisher,
    private readonly emailSender: EmailSender,
    private readonly clock: Clock,
    private readonly tokenTtlSeconds: number,
  ) {}

  async execute(input: IssueEmailVerificationInput): Promise<void> {
    const user = await this.users.findById(input.userId);
    if (!user) return; // user gone — silently skip; nothing to do
    if (user.isEmailVerified()) return;

    const now = this.clock.now();
    const code = this.codeHasher.generate();
    const expiresAt = new Date(now.getTime() + this.tokenTtlSeconds * 1000);

    const newToken = EmailVerificationToken.issue({
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

    // Send AFTER commit. If delivery fails the user can resend; we don't
    // want to roll back the persisted token (which would lose the audit
    // trail of "we tried"). The Resend adapter throws on failure — let
    // that bubble; the subscriber wrapper will log it.
    const { subject, html, text } = verificationTemplate({ code: code.plaintext });
    await this.emailSender.send({ to: user.email.value, subject, html, text });
  }
}
