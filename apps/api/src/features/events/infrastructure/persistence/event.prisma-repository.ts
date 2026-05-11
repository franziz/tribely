import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Event } from '../../domain/entities/event.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';
import { toEvent, toRow } from './event.mapper.js';

export class EventPrismaRepository implements EventRepository {
  constructor(private readonly db: Db) {}

  async findById(id: string, ctx?: TxContext): Promise<Event | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
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
}
