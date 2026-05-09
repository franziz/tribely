import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { refreshTokenIssued } from '../events/refresh-token-issued.event.js';
import {
  refreshTokenRevoked,
  type RefreshTokenRevokedReason,
} from '../events/refresh-token-revoked.event.js';
import { refreshTokenRotated } from '../events/refresh-token-rotated.event.js';
import { refreshTokenReuseDetected } from '../events/refresh-token-reuse-detected.event.js';

/**
 * RefreshToken aggregate root — represents one logical session for a user.
 *
 * Construction:
 *   - issue(...) — first-time issue at sign-up / sign-in. Records issued event.
 *   - rehydrate(...) — from persistence. No events.
 *
 * State changes (each records an event):
 *   - rotate(newId, now) — invoked on /auth/refresh. Marks this token revoked
 *     with reason='rotated' and points rotatedToId at the new token. The new
 *     token is created separately via issue(...).
 *   - revoke(reason, now) — generic revocation: signed_out / sign_out_all.
 *   - markReuseDetected(now) — called when a token whose revokedAt is set is
 *     presented again. Records reuse-detected event but does NOT itself revoke
 *     anything else; the use case decides the blast radius (typically: revoke
 *     all of the user's tokens).
 */
export class RefreshToken extends AggregateRoot {
  private constructor(
    public readonly id: string,
    public readonly userId: string,
    public readonly tokenHash: string,
    public readonly issuedAt: Date,
    public readonly expiresAt: Date,
    private _revokedAt: Date | null,
    private _revokedReason: RefreshTokenRevokedReason | null,
    private _lastUsedAt: Date | null,
    private _rotatedToId: string | null,
    public readonly deviceLabel: string | null,
  ) {
    super();
  }

  static issue(input: {
    id: string;
    userId: string;
    tokenHash: string;
    expiresAt: Date;
    deviceLabel: string | null;
    now: Date;
  }): RefreshToken {
    const token = new RefreshToken(
      input.id,
      input.userId,
      input.tokenHash,
      input.now,
      input.expiresAt,
      null,
      null,
      null,
      null,
      input.deviceLabel,
    );
    token.record(
      refreshTokenIssued({
        refreshTokenId: input.id,
        userId: input.userId,
        issuedAt: input.now.toISOString(),
        expiresAt: input.expiresAt.toISOString(),
        deviceLabel: input.deviceLabel,
      }),
    );
    return token;
  }

  static rehydrate(state: {
    id: string;
    userId: string;
    tokenHash: string;
    issuedAt: Date;
    expiresAt: Date;
    revokedAt: Date | null;
    revokedReason: RefreshTokenRevokedReason | null;
    lastUsedAt: Date | null;
    rotatedToId: string | null;
    deviceLabel: string | null;
  }): RefreshToken {
    return new RefreshToken(
      state.id,
      state.userId,
      state.tokenHash,
      state.issuedAt,
      state.expiresAt,
      state.revokedAt,
      state.revokedReason,
      state.lastUsedAt,
      state.rotatedToId,
      state.deviceLabel,
    );
  }

  get revokedAt(): Date | null {
    return this._revokedAt;
  }

  get revokedReason(): RefreshTokenRevokedReason | null {
    return this._revokedReason;
  }

  get lastUsedAt(): Date | null {
    return this._lastUsedAt;
  }

  get rotatedToId(): string | null {
    return this._rotatedToId;
  }

  isRevoked(): boolean {
    return this._revokedAt !== null;
  }

  isExpired(now: Date): boolean {
    return now >= this.expiresAt;
  }

  isUsable(now: Date): boolean {
    return !this.isRevoked() && !this.isExpired(now);
  }

  rotate(newId: string, now: Date): void {
    if (this.isRevoked()) {
      throw new Error('Cannot rotate an already-revoked refresh token');
    }
    this._revokedAt = now;
    this._revokedReason = 'rotated';
    this._rotatedToId = newId;
    this._lastUsedAt = now;
    this.record(
      refreshTokenRotated({
        refreshTokenId: this.id,
        userId: this.userId,
        rotatedToId: newId,
        rotatedAt: now.toISOString(),
      }),
    );
    this.record(
      refreshTokenRevoked({
        refreshTokenId: this.id,
        userId: this.userId,
        reason: 'rotated',
        revokedAt: now.toISOString(),
      }),
    );
  }

  revoke(reason: RefreshTokenRevokedReason, now: Date): void {
    if (this.isRevoked()) return; // idempotent
    this._revokedAt = now;
    this._revokedReason = reason;
    this.record(
      refreshTokenRevoked({
        refreshTokenId: this.id,
        userId: this.userId,
        reason,
        revokedAt: now.toISOString(),
      }),
    );
  }

  markReuseDetected(now: Date): void {
    this.record(
      refreshTokenReuseDetected({
        refreshTokenId: this.id,
        userId: this.userId,
        detectedAt: now.toISOString(),
      }),
    );
  }
}
