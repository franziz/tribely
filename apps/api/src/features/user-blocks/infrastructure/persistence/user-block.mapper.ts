import type { UserBlock as UserBlockRow, Prisma } from '@prisma/client';
import { UserBlock } from '../../domain/entities/user-block.js';

/**
 * Reconstruct a UserBlock aggregate from a Prisma row.
 */
export const toUserBlock = (row: UserBlockRow): UserBlock =>
  UserBlock.rehydrate({
    id: row.id,
    initiatorUserId: row.initiatorUserId,
    blockedUserId: row.blockedUserId,
    createdAt: row.createdAt,
  });

/**
 * Project a UserBlock aggregate to a Prisma create payload.
 */
export const toRow = (block: UserBlock): Prisma.UserBlockUncheckedCreateInput => ({
  id: block.id,
  initiatorUserId: block.initiatorUserId,
  blockedUserId: block.blockedUserId,
  createdAt: block.createdAt,
});
