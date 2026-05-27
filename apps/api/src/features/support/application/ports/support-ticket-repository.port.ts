import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { SupportTicket } from '../../domain/entities/support-ticket.js';

export interface SupportTicketRepository {
  save(ticket: SupportTicket, ctx?: TxContext): Promise<void>;

  /**
   * Count tickets submitted by a user since `sinceMs` (epoch milliseconds).
   * Used to enforce the 5-per-24h rate limit in SubmitSupportTicketUseCase.
   */
  countRecentByUser(userId: string, sinceMs: number, ctx?: TxContext): Promise<number>;
}
