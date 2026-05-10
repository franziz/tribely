import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { emailVerificationConsumed } from '../events/email-verification-consumed.event.js';
import {
  emailVerificationInvalidated,
  type EmailVerificationInvalidatedReason,
} from '../events/email-verification-invalidated.event.js';
import { emailVerificationIssued } from '../events/email-verification-issued.event.js';

/**
 * Maximum wrong-code submissions before a token self-invalidates. The 6-digit
 * code's search space is 1M, so a 5-attempt cap keeps brute-force probability
 * at 5/1,000,000 per token. Combined with the 1/min/user resend rate-limit and
 * single-open-token invariant, this is conservative.
 */
export const EMAIL_VERIFICATION_MAX_ATTEMPTS = 5;

/**
 * EmailVerificationToken aggregate root — one open token per user at a time.
 *
 * The plaintext 6-digit code is shown to the user via email; only the hash is
 * persisted (SHA-256 over the plaintext). This is sufficient because the user
 * scope is implicit at verify time (the verify endpoint is auth-required) and
 * the attempts cap defeats brute-force.
 *
 * Construction:
 *   - issue(...) — first-time issue, records issued event.
 *   - rehydrate(...) — from persistence, no events.
 *
 * State transitions (each records an event):
 *   - consume(now) — successful match. Marks consumed.
 *   - registerFailedAttempt(now) — wrong code submitted. Increments attempts;
 *     auto-invalidates with reason='too_many_attempts' once cap is hit.
 *   - invalidate(reason, now) — caller-driven invalidation, e.g. 'replaced'
 *     when issuing a new token, or 'already_verified' when the user is already
 *     verified.
 */
export class EmailVerificationToken extends AggregateRoot {
  private constructor(
    public readonly id: string,
    public readonly userId: string,
    public readonly codeHash: string,
    public readonly issuedAt: Date,
    public readonly expiresAt: Date,
    private _consumedAt: Date | null,
    private _attempts: number,
    private _invalidated: boolean,
  ) {
    super();
  }

  static issue(input: {
    id: string;
    userId: string;
    codeHash: string;
    expiresAt: Date;
    now: Date;
  }): EmailVerificationToken {
    const token = new EmailVerificationToken(
      input.id,
      input.userId,
      input.codeHash,
      input.now,
      input.expiresAt,
      null,
      0,
      false,
    );
    token.record(
      emailVerificationIssued({
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
  }): EmailVerificationToken {
    return new EmailVerificationToken(
      state.id,
      state.userId,
      state.codeHash,
      state.issuedAt,
      state.expiresAt,
      state.consumedAt,
      state.attempts,
      state.invalidated,
    );
  }

  get consumedAt(): Date | null {
    return this._consumedAt;
  }

  get attempts(): number {
    return this._attempts;
  }

  get invalidated(): boolean {
    return this._invalidated;
  }

  isConsumed(): boolean {
    return this._consumedAt !== null;
  }

  isExpired(now: Date): boolean {
    return now >= this.expiresAt;
  }

  isOpen(now: Date): boolean {
    return !this.isConsumed() && !this._invalidated && !this.isExpired(now);
  }

  consume(now: Date): void {
    if (this._consumedAt !== null) return; // idempotent
    if (this._invalidated) {
      throw new Error('Cannot consume an invalidated email verification token');
    }
    if (this.isExpired(now)) {
      throw new Error('Cannot consume an expired email verification token');
    }
    this._consumedAt = now;
    this.record(
      emailVerificationConsumed({
        tokenId: this.id,
        userId: this.userId,
        consumedAt: now.toISOString(),
      }),
    );
  }

  registerFailedAttempt(now: Date): void {
    if (this._invalidated || this._consumedAt !== null) return;
    this._attempts += 1;
    if (this._attempts >= EMAIL_VERIFICATION_MAX_ATTEMPTS) {
      this.invalidate('too_many_attempts', now);
    }
  }

  invalidate(reason: EmailVerificationInvalidatedReason, now: Date): void {
    if (this._invalidated) return; // idempotent
    this._invalidated = true;
    this.record(
      emailVerificationInvalidated({
        tokenId: this.id,
        userId: this.userId,
        reason,
        invalidatedAt: now.toISOString(),
      }),
    );
  }
}
