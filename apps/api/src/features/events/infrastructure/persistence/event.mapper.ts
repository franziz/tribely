import type { Event as EventRow, Prisma } from '@prisma/client';
import { AppError } from '@/core/errors/app-error.js';
import {
  Event,
  type ApprovalMode,
  type CostSplit,
  type EventStatus,
} from '../../domain/entities/event.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
import { Venue } from '../../domain/value-objects/venue.js';

const STATUSES = ['draft', 'published', 'cancelled', 'completed'] as const;
const COST_SPLITS = ['own', 'host_paid', 'split'] as const;
const APPROVAL_MODES = ['auto', 'manual'] as const;

const isStatus = (s: string): s is EventStatus => (STATUSES as readonly string[]).includes(s);
const isCostSplit = (s: string): s is CostSplit => (COST_SPLITS as readonly string[]).includes(s);
const isApprovalMode = (s: string): s is ApprovalMode =>
  (APPROVAL_MODES as readonly string[]).includes(s);

/**
 * Reconstruct an Event aggregate from a Prisma row.
 *
 * Throws `AppError.internal` if a string column doesn't match its expected
 * union — that would be a data-integrity bug worth surfacing loudly (likely
 * a migration mismatch or someone wrote to the DB out-of-band).
 */
export const toEvent = (row: EventRow): Event => {
  if (!isStatus(row.status)) {
    throw AppError.internal(`Invalid event status in DB row ${row.id}: ${row.status}`);
  }
  if (!isCostSplit(row.costSplit)) {
    throw AppError.internal(`Invalid event costSplit in DB row ${row.id}: ${row.costSplit}`);
  }
  if (!isApprovalMode(row.approvalMode)) {
    throw AppError.internal(`Invalid event approvalMode in DB row ${row.id}: ${row.approvalMode}`);
  }
  return Event.rehydrate({
    id: row.id,
    hostUserId: row.hostUserId,
    title: row.title,
    description: row.description,
    venue: Venue.create({
      address: row.venueAddress,
      city: row.venueCity,
      latitude: row.venueLatitude.toNumber(),
      longitude: row.venueLongitude.toNumber(),
    }),
    startsAt: row.startsAt,
    endsAt: row.endsAt,
    capacity: Capacity.create(row.capacity),
    category: EventCategory.create(row.category),
    costSplit: row.costSplit,
    approvalMode: row.approvalMode,
    status: row.status,
    cancellationReason: row.cancellationReason,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  });
};

/**
 * Project an Event aggregate to a Prisma create/update payload.
 *
 * Returns Prisma's input type (not the row type) so Decimal columns accept
 * a `number` directly — Prisma converts to its `Decimal` representation.
 */
export const toRow = (event: Event): Prisma.EventUncheckedCreateInput => ({
  id: event.id,
  hostUserId: event.hostUserId,
  title: event.title,
  description: event.description,
  venueAddress: event.venue.address,
  venueCity: event.venue.city,
  venueLatitude: event.venue.latitude,
  venueLongitude: event.venue.longitude,
  startsAt: event.startsAt,
  endsAt: event.endsAt,
  capacity: event.capacity.value,
  category: event.category.value,
  costSplit: event.costSplit,
  approvalMode: event.approvalMode,
  status: event.status,
  cancellationReason: event.cancellationReason,
  createdAt: event.createdAt,
  updatedAt: event.updatedAt,
});
