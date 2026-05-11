import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { passwordResetRequested } from '../events/password-reset-requested.event.js';
import { passwordResetTokenConsumed } from '../events/password-reset-token-consumed.event.js';
import {
  passwordResetTokenInvalidated,
  type PasswordResetTokenInvalidatedReason,
} from '../events/password-reset-token-invalidated.event.js';
import { OneTimeCodeLifecycle } from '../value-objects/one-time-code-lifecycle.js';

/**
 * PasswordResetToken aggregate root — one open token per user at a time.
 *
 * Same shape as EmailVerificationToken (both compose `OneTimeCodeLifecycle`)
 * but a separate aggregate, separate persistence table, and a separate
 * event vocabulary so consumers and audit logs see clean signals (no
 * discriminator field, no shared topic).
 *
 * Construction:
 *   - issue(...) — first-time issue, records `auth.passwordResetRequested`.
 *   - rehydrate(...) — from persistence, no events.
 *
 * State transitions:
 *   - consume(now) — successful match. Marks consumed; records
 *     `auth.passwordResetTokenConsumed`. The companion `auth.passwordReset`
 *     event is emitted by the Credential aggregate when its password is
 *     actually changed in the same UnitOfWork.
 *   - registerFailedAttempt(now) — wrong code submitted. Increments attempts;
 *     auto-invalidates with reason='too_many_attempts' once cap is hit.
 *   - invalidate(reason, now) — caller-driven invalidation, e.g. 'replaced'
 *     when issuing a new token over an existing open one.
 */
export class PasswordResetToken extends AggregateRoot {
  private constructor(
    public readonly id: string,
    public readonly userId: string,
    private readonly lifecycle: OneTimeCodeLifecycle,
  ) {
    super();
  }

  static issue(input: {
    id: string;
    userId: string;
    codeHash: string;
    expiresAt: Date;
    now: Date;
  }): PasswordResetToken {
    const lifecycle = OneTimeCodeLifecycle.create({
      codeHash: input.codeHash,
      issuedAt: input.now,
      expiresAt: input.expiresAt,
    });
    const token = new PasswordResetToken(input.id, input.userId, lifecycle);
    token.record(
      passwordResetRequested({
        tokenId: input.id,
        userId: input.userId,
        issuedAt: input.now.toISOString(),
        expiresAt: input.expiresAt.toISOString(),
      }),
    );
    return token;
  }

  static rehydrate(state: {
    id: string;
    userId: string;
    codeHash: string;
    issuedAt: Date;
    expiresAt: Date;
    consumedAt: Date | null;
    attempts: number;
    invalidated: boolean;
  }): PasswordResetToken {
    const lifecycle = OneTimeCodeLifecycle.rehydrate({
      codeHash: state.codeHash,
      issuedAt: state.issuedAt,
      expiresAt: state.expiresAt,
      consumedAt: state.consumedAt,
      attempts: state.attempts,
      invalidated: state.invalidated,
    });
    return new PasswordResetToken(state.id, state.userId, lifecycle);
  }

  get codeHash(): string {
    return this.lifecycle.codeHash;
  }

  get issuedAt(): Date {
    return this.lifecycle.issuedAt;
  }

  get expiresAt(): Date {
    return this.lifecycle.expiresAt;
  }

  get consumedAt(): Date | null {
    return this.lifecycle.consumedAt;
  }

  get attempts(): number {
    return this.lifecycle.attempts;
  }

  get invalidated(): boolean {
    return this.lifecycle.invalidated;
  }

  isConsumed(): boolean {
    return this.lifecycle.isConsumed();
  }

  isExpired(now: Date): boolean {
    return this.lifecycle.isExpired(now);
  }

  isOpen(now: Date): boolean {
    return this.lifecycle.isOpen(now);
  }

  consume(now: Date): void {
    const result = this.lifecycle.consume(now);
    if (result.wasAlreadyConsumed) return;
    this.record(
      passwordResetTokenConsumed({
        tokenId: this.id,
        userId: this.userId,
        consumedAt: now.toISOString(),
      }),
    );
  }

  registerFailedAttempt(now: Date): void {
    const result = this.lifecycle.registerFailedAttempt(now);
    if (result.becameInvalid) {
      this.record(
        passwordResetTokenInvalidated({
          tokenId: this.id,
          userId: this.userId,
          reason: 'too_many_attempts',
          invalidatedAt: now.toISOString(),
        }),
      );
    }
  }

  invalidate(reason: PasswordResetTokenInvalidatedReason, now: Date): void {
    const result = this.lifecycle.invalidate(now);
    if (result.wasAlreadyInvalidated) return;
    this.record(
      passwordResetTokenInvalidated({
        tokenId: this.id,
        userId: this.userId,
        reason,
        invalidatedAt: now.toISOString(),
      }),
    );
  }
}
