import type { Prisma } from '@prisma/client';
import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Event } from '../../domain/entities/event.js';
import type {
  EventRepository,
  ListEventsCursor,
  ListEventsFilters,
  ListEventsPage,
} from '../../domain/repositories/event.repository.js';
import { toEvent, toRow } from './event.mapper.js';

export class EventPrismaRepository implements EventRepository {
  constructor(private readonly db: Db) {}

  async findById(id: string, ctx?: TxContext): Promise<Event | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.event.findUnique({ where: { id } });
    return row ? toEvent(row) : null;
  }

  async findByIdForUpdate(id: string, ctx: TxContext): Promise<Event | null> {
    const client = unwrapTx(ctx);
    // Acquire the row lock first. Prisma doesn't expose `FOR UPDATE` on
    // `findUnique`, so we use $queryRaw (tagged template → bound params, no
    // injection risk). If the row doesn't exist, this returns 0 rows — safe.
    // If another tx holds the lock, this blocks until that tx commits or
    // rolls back. The lock is released when the surrounding UnitOfWork.run
    // transaction ends.
    await client.$queryRaw`SELECT id FROM events WHERE id = ${id} FOR UPDATE`;
    const row = await client.event.findUnique({ where: { id } });
    return row ? toEvent(row) : null;
  }

  async save(event: Event, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    // `create` uses the full row projection (id, createdAt, ...). `update`
    // sources from the aggregate's strict-typed getters — keeps Prisma's
    // `EventUpdateInput` happy under `exactOptionalPropertyTypes`, since
    // `Prisma.EventUncheckedCreateInput` permits `undefined` on optional
    // columns and that doesn't fit the stricter update input shape.
    await client.event.upsert({
      where: { id: event.id },
      create: toRow(event),
      update: {
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
        updatedAt: event.updatedAt,
      },
    });
  }

  async findManyForListing(
    filters: ListEventsFilters,
    cursor: ListEventsCursor | null,
    limit: number,
    ctx?: TxContext,
  ): Promise<ListEventsPage> {
    const client = ctx ? unwrapTx(ctx) : this.db;

    // `startsAt` may receive both `gte/lte` (window filter) and a cursor
    // predicate — Prisma allows compound conditions inside a single field
    // filter object, but to keep the construction readable we layer them via
    // explicit AND clauses.
    const filterClauses: Prisma.EventWhereInput[] = [
      { status: 'published' },
      { endsAt: { gt: filters.now } },
    ];
    if (filters.city !== undefined) filterClauses.push({ venueCity: filters.city });
    if (filters.category !== undefined) filterClauses.push({ category: filters.category });
    if (filters.from !== undefined) filterClauses.push({ startsAt: { gte: filters.from } });
    if (filters.to !== undefined) filterClauses.push({ startsAt: { lte: filters.to } });
    if (filters.hostUserId !== undefined) filterClauses.push({ hostUserId: filters.hostUserId });
    if (cursor) {
      filterClauses.push({
        OR: [
          { startsAt: { gt: cursor.lastStartsAt } },
          {
            AND: [{ startsAt: cursor.lastStartsAt }, { id: { gt: cursor.lastEventId } }],
          },
        ],
      });
    }

    const rows = await client.event.findMany({
      where: { AND: filterClauses },
      orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
      take: limit + 1,
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    const events = page.map(toEvent);
    const last = page.at(-1);
    const nextCursor: ListEventsCursor | null =
      hasMore && last ? { lastStartsAt: last.startsAt, lastEventId: last.id } : null;

    return { events, nextCursor };
  }
}
