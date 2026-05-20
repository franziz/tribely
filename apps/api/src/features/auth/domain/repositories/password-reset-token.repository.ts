import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { PasswordResetToken } from '../entities/password-reset-token.js';

export interface PasswordResetTokenRepository {
  findById(id: string, ctx?: TxContext): Promise<PasswordResetToken | null>;
  /**
   * Returns the single open token for a user, or null. "Open" = not consumed,
   * not invalidated, not expired at the time of query. Callers re-check
   * isOpen() against `now` since clock drift between query and validation is
   * tiny but non-zero.
   */
  findOpenByUserId(userId: string, ctx?: TxContext): Promise<PasswordResetToken | null>;
  save(token: PasswordResetToken, ctx?: TxContext): Promise<void>;
  /**
   * Hard-delete ALL password reset tokens for the given user.
   * Used exclusively in the account-deletion cascade.
   * Returns the count of deleted rows.
   */
  deleteAllForUser(userId: string, ctx: TxContext): Promise<number>;
}
