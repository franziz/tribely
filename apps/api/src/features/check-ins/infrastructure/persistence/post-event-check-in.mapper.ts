import type { PostEventCheckIn as PostEventCheckInRow, Prisma } from '@prisma/client';
import { AppError } from '@/core/errors/app-error.js';
import { PostEventCheckIn, type CheckInStatus } from '../../domain/entities/post-event-check-in.js';

const STATUSES = ['pending', 'ok', 'flagged'] as const;
const isStatus = (s: string): s is CheckInStatus => (STATUSES as readonly string[]).includes(s);

/**
 * Reconstruct a PostEventCheckIn aggregate from a Prisma row.
 *
 * Throws `AppError.internal` if the status column doesn't match the expected
 * union — that is a data-integrity bug worth surfacing loudly.
 */
export const toCheckIn = (row: PostEventCheckInRow): PostEventCheckIn => {
  if (!isStatus(row.status)) {
    throw AppError.internal(`Invalid check-in status in DB row ${row.id}: ${row.status}`);
  }
  return PostEventCheckIn.rehydrate({
    id: row.id,
    userId: row.userId,
    eventId: row.eventId,
    hostUserId: row.hostUserId,
    status: row.status,
    createdAt: row.createdAt,
    acknowledgedAt: row.acknowledgedAt,
    flaggedAt: row.flaggedAt,
    reportBody: row.reportBody,
    resolvedAt: row.resolvedAt,
  });
};

/**
 * Project a PostEventCheckIn aggregate to a Prisma create input payload.
 */
export const toRow = (checkIn: PostEventCheckIn): Prisma.PostEventCheckInUncheckedCreateInput => ({
  id: checkIn.id,
  userId: checkIn.userId,
  eventId: checkIn.eventId,
  hostUserId: checkIn.hostUserId,
  status: checkIn.status,
  createdAt: checkIn.createdAt,
  acknowledgedAt: checkIn.acknowledgedAt,
  flaggedAt: checkIn.flaggedAt,
  reportBody: checkIn.reportBody,
  resolvedAt: checkIn.resolvedAt,
});
