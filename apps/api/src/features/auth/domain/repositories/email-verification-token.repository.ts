import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { EmailVerificationToken } from '../entities/email-verification-token.js';

export interface EmailVerificationTokenRepository {
  findById(id: string, ctx?: TxContext): Promise<EmailVerificationToken | null>;
  /**
   * Returns the single open token for a user, or null. "Open" = not consumed,
   * not invalidated, not expired at the time of query. Callers re-check
   * isOpen() against `now` since clock drift between query and validation is
   * tiny but non-zero.
   */
  findOpenByUserId(userId: string, ctx?: TxContext): Promise<EmailVerificationToken | null>;
  save(token: EmailVerificationToken, ctx?: TxContext): Promise<void>;
}
