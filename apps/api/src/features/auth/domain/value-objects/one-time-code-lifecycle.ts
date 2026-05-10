/**
 * Maximum wrong-code submissions before a one-time code self-invalidates.
 * The 6-digit code's search space is 1M, so a 5-attempt cap keeps brute-force
 * probability at 5/1,000,000 per code. Combined with rate-limits and the
 * single-open-token-per-purpose invariant, this is conservative.
 */
export const ONE_TIME_CODE_MAX_ATTEMPTS = 5;

/**
 * Shared lifecycle state for one-time code aggregates (email verification,
 * password reset, and any future MFA / magic-link / invite codes).
 *
 * Each aggregate composes one of these: identity (id, userId), purpose-specific
 * events, and persistence are owned by the aggregate; the codeHash + expiry +
 * attempts/consumed/invalidated state-machine lives here. This keeps each
 * aggregate's event vocabulary clean (auditors and consumers see
 * `auth.passwordResetRequested`, not a polluted shared event), while removing
 * the duplication between near-identical state machines.
 *
 * Mutable on purpose — matches the existing aggregate style of in-place
 * mutation. Aggregates record their domain events AFTER calling the
 * corresponding lifecycle method.
 */
export class OneTimeCodeLifecycle {
  private constructor(
    public readonly codeHash: string,
    public readonly issuedAt: Date,
    public readonly expiresAt: Date,
    private _consumedAt: Date | null,
    private _attempts: number,
    private _invalidated: boolean,
  ) {}

  static create(input: {
    codeHash: string;
    issuedAt: Date;
    expiresAt: Date;
  }): OneTimeCodeLifecycle {
    return new OneTimeCodeLifecycle(
      input.codeHash,
      input.issuedAt,
      input.expiresAt,
      null,
      0,
      false,
    );
  }

  static rehydrate(state: {
    codeHash: string;
    issuedAt: Date;
    expiresAt: Date;
    consumedAt: Date | null;
    attempts: number;
    invalidated: boolean;
  }): OneTimeCodeLifecycle {
    return new OneTimeCodeLifecycle(
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

  /**
   * Marks the code consumed. Idempotent — second call is a no-op.
   * Throws if the code is invalidated or expired (caller must check `isOpen`
   * first to surface a meaningful application error).
   */
  consume(now: Date): { wasAlreadyConsumed: boolean } {
    if (this._consumedAt !== null) return { wasAlreadyConsumed: true };
    if (this._invalidated) {
      throw new Error('Cannot consume an invalidated one-time code');
    }
    if (this.isExpired(now)) {
      throw new Error('Cannot consume an expired one-time code');
    }
    this._consumedAt = now;
    return { wasAlreadyConsumed: false };
  }

  /**
   * Increment the failed-attempt counter. Auto-invalidates once the cap is
   * hit. Returns whether the cap was reached so the caller can record the
   * appropriate "too_many_attempts" invalidation event in addition to the
   * failed-attempt signal it owns.
   *
   * No-op once the lifecycle is invalidated or consumed (defends against a
   * stale request hitting an already-resolved code).
   */
  registerFailedAttempt(now: Date): { recorded: boolean; becameInvalid: boolean } {
    if (this._invalidated || this._consumedAt !== null) {
      return { recorded: false, becameInvalid: false };
    }
    this._attempts += 1;
    if (this._attempts >= ONE_TIME_CODE_MAX_ATTEMPTS) {
      this._invalidated = true;
      return { recorded: true, becameInvalid: true };
    }
    // `now` is reserved for future per-attempt audit; keep the parameter for
    // signature stability so callers don't have to guess when an aggregate
    // adds richer auditing.
    void now;
    return { recorded: true, becameInvalid: false };
  }

  /**
   * Caller-driven invalidation. Idempotent — second call is a no-op (returns
   * `wasAlreadyInvalidated: true`) so duplicate event delivery doesn't
   * double-record an invalidation event.
   */
  invalidate(now: Date): { wasAlreadyInvalidated: boolean } {
    if (this._invalidated) return { wasAlreadyInvalidated: true };
    this._invalidated = true;
    void now;
    return { wasAlreadyInvalidated: false };
  }
}
