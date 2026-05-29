import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { SupportTicket } from '../entities/support-ticket.js';

export interface SupportTicketRepository {
  save(ticket: SupportTicket, ctx?: TxContext): Promise<void>;

  /**
   * Count tickets submitted by a user since `since` (Date).
   * Used to enforce the 5-per-24h rate limit in SubmitSupportTicketUseCase.
   */
  countRecentByUser(userId: string, since: Date, ctx?: TxContext): Promise<number>;

  /**
   * PDPA-deletion carve-out (TRI-217) — required-ctx evidence-integrity pattern.
   *
   * Pseudonymises all support tickets owned by the given user:
   *   - `userId`            → NULL
   *   - `userEmailSnapshot` → NULL
   *   - `message`           → '[deleted]' (sentinel; NOT NULL column — overwrite, do NOT null)
   *
   * Ticket rows are RETAINED for audit continuity; only the three PII-bearing
   * fields above are scrubbed. `category`, `status`, `createdAt`, `resolvedAt`,
   * and `reportId` are left untouched.
   *
   * `ctx` is non-optional: the UPDATE must commit atomically with the triggering
   * account-deletion transaction. A scrub that commits outside that tx is a
   * PDPA s25 minimisation incident, not merely an observability gap.
   *
   * Returns the number of rows scrubbed.
   */
  pseudonymiseForUser(userId: string, ctx: TxContext): Promise<number>;
}
