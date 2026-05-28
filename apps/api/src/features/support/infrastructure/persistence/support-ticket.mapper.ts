import type { SupportTicket as SupportTicketRow, Prisma } from '@prisma/client';
import { SupportTicket } from '../../domain/entities/support-ticket.js';
import { SupportCategory } from '../../domain/value-objects/support-category.js';
import { SupportMessage } from '../../domain/value-objects/support-message.js';

/**
 * Reconstruct a SupportTicket aggregate from a Prisma row.
 */
export const toSupportTicket = (row: SupportTicketRow): SupportTicket =>
  SupportTicket.rehydrate({
    id: row.id,
    userId: row.userId,
    userEmailSnapshot: row.userEmailSnapshot,
    category: SupportCategory.create(row.category),
    message: SupportMessage.create(row.message),
    reportId: row.reportId,
    status: row.status,
    createdAt: row.createdAt,
    resolvedAt: row.resolvedAt,
  });

/**
 * Project a SupportTicket aggregate to a Prisma create input.
 */
export const toRow = (entity: SupportTicket): Prisma.SupportTicketUncheckedCreateInput => ({
  id: entity.id,
  userId: entity.userId,
  userEmailSnapshot: entity.userEmailSnapshot,
  category: entity.category.value,
  message: entity.message.value,
  reportId: entity.reportId,
  status: entity.status,
  createdAt: entity.createdAt,
  resolvedAt: entity.resolvedAt,
});
