import type { Selfie as SelfieRow, Prisma } from '@prisma/client';
import { AppError } from '@/core/errors/app-error.js';
import { Selfie } from '../../domain/entities/selfie.js';
import { SelfieStatus } from '../../domain/value-objects/selfie-status.js';

const isStatus = (
  s: string,
): s is import('../../domain/value-objects/selfie-status.js').SelfieStatusValue =>
  SelfieStatus.isValid(s);

/**
 * Reconstruct a Selfie aggregate from a Prisma row.
 *
 * Throws `AppError.internal` if `status` doesn't match its expected union —
 * that's a data-integrity bug worth surfacing loudly (most likely a migration
 * mismatch or someone wrote to the DB out-of-band).
 */
export const toSelfie = (row: SelfieRow): Selfie => {
  if (!isStatus(row.status)) {
    throw AppError.internal(`Invalid selfie status in DB row ${row.id}: "${row.status}"`);
  }
  return Selfie.rehydrate({
    id: row.id,
    userId: row.userId,
    status: row.status,
    storageKey: row.storageKey,
    approvedAt: row.approvedAt,
    rejectedAt: row.rejectedAt,
    deletedAt: row.deletedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  });
};

/**
 * Project a Selfie aggregate to a Prisma create payload.
 * All nullable fields are projected explicitly so an upsert `create` branch
 * doesn't fall back to Prisma defaults silently.
 */
export const toRow = (selfie: Selfie): Prisma.SelfieUncheckedCreateInput => ({
  id: selfie.id,
  userId: selfie.userId,
  status: selfie.status,
  storageKey: selfie.storageKey,
  approvedAt: selfie.approvedAt,
  rejectedAt: selfie.rejectedAt,
  deletedAt: selfie.deletedAt,
  createdAt: selfie.createdAt,
  updatedAt: selfie.updatedAt,
});
