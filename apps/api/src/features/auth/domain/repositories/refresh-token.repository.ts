import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { RefreshToken } from '../entities/refresh-token.js';
import type { RefreshTokenRevokedReason } from '../events/refresh-token-revoked.event.js';

export interface RefreshTokenRepository {
  findByTokenHash(hash: string, ctx?: TxContext): Promise<RefreshToken | null>;
  findById(id: string, ctx?: TxContext): Promise<RefreshToken | null>;
  save(token: RefreshToken, ctx?: TxContext): Promise<void>;
  /**
   * Mark every active (non-revoked) token for the user as revoked.
   * Used by sign-out-all and by reuse-detection response.
   * Returns the list of tokens that were revoked (so the caller can
   * publish events for them inside the same UnitOfWork).
   */
  revokeAllActiveForUser(
    userId: string,
    reason: RefreshTokenRevokedReason,
    now: Date,
    ctx?: TxContext,
  ): Promise<RefreshToken[]>;
  /**
   * Hard-delete ALL refresh tokens for the given user regardless of revocation state.
   * Used exclusively in the account-deletion cascade — NOT for sign-out.
   * Hard-delete is strictly stronger than revoke: no row means no lookup is possible,
   * satisfying the "no plaintext lookup table retained" requirement.
   * Returns the count of deleted rows.
   */
  deleteAllForUser(userId: string, ctx: TxContext): Promise<number>;
}
