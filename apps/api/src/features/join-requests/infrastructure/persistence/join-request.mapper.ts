import type { JoinRequest as JoinRequestRow, Prisma } from '@prisma/client';
import { AppError } from '@/core/errors/app-error.js';
import { JoinRequest, type JoinRequestStatus } from '../../domain/entities/join-request.js';

const STATUSES = ['pending', 'approved', 'rejected', 'cancelled', 'removed_by_host'] as const;

const isStatus = (s: string): s is JoinRequestStatus => (STATUSES as readonly string[]).includes(s);

/**
 * Reconstruct a JoinRequest aggregate from a Prisma row.
 *
 * Throws `AppError.internal` if `status` doesn't match its expected union —
 * that's a data-integrity bug worth surfacing loudly (most likely a migration
 * mismatch or someone wrote to the DB out-of-band).
 */
export const toJoinRequest = (row: JoinRequestRow): JoinRequest => {
  if (!isStatus(row.status)) {
    throw AppError.internal(`Invalid join request status in DB row ${row.id}: ${row.status}`);
  }
  return JoinRequest.rehydrate({
    id: row.id,
    eventId: row.eventId,
    requesterUserId: row.requesterUserId,
    requestedAt: row.requestedAt,
    status: row.status,
    decidedAt: row.decidedAt,
    decidedByUserId: row.decidedByUserId,
    decisionReason: row.decisionReason,
  });
};

/**
 * Project a JoinRequest aggregate to a Prisma create payload. All nullable
 * decision fields are projected explicitly so an upsert `create` branch
 * doesn't fall back to Prisma defaults silently.
 */
export const toRow = (jr: JoinRequest): Prisma.JoinRequestUncheckedCreateInput => ({
  id: jr.id,
  eventId: jr.eventId,
  requesterUserId: jr.requesterUserId,
  status: jr.status,
  requestedAt: jr.requestedAt,
  decidedAt: jr.decidedAt,
  decidedByUserId: jr.decidedByUserId,
  decisionReason: jr.decisionReason,
});
