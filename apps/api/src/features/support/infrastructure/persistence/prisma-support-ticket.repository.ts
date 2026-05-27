import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { SupportTicket } from '../../domain/entities/support-ticket.js';
import type { SupportTicketRepository } from '../../application/ports/support-ticket-repository.port.js';
import { toRow } from './support-ticket.mapper.js';

/**
 * Prisma-backed implementation of SupportTicketRepository.
 *
 * `userId` is stored as a nullable free-text column with no FK — pseudonymise-
 * by-repo pattern (TRI-29 / TRI-134 precedent): the ticket survives account
 * tombstone without requiring a cascade delete on the support side.
 *
 * `reportId` is stored as free-text — legal-compliance guardrail: support
 * persistence MUST NOT join to `moderation_reports`.
 */
export class PrismaSupportTicketRepository implements SupportTicketRepository {
  constructor(private readonly db: Db) {}

  async save(ticket: SupportTicket, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    await client.supportTicket.create({ data: toRow(ticket) });
  }

  async countRecentByUser(userId: string, sinceMs: number, ctx?: TxContext): Promise<number> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    return client.supportTicket.count({
      where: {
        userId,
        createdAt: { gte: new Date(sinceMs) },
      },
    });
  }
}
