// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { runWithContext } from '@/core/context/request-context.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import { OutboxEventPublisher } from '@/core/events/outbox-event-publisher.js';

import { Event } from '../../domain/entities/event.js';
import { EVENT_CANCELLED } from '../../domain/events/event-cancelled.event.js';
import { EVENT_CREATED } from '../../domain/events/event-created.event.js';
import { EVENT_PUBLISHED } from '../../domain/events/event-published.event.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
import { Venue } from '../../domain/value-objects/venue.js';
import { EventPrismaRepository } from './event.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * End-to-end repository test (the AC says: save → query → modify → emit event).
 * Uses the real Prisma client against the Postgres service container in CI
 * (`.github/workflows/_api.yml`) or the local Neon dev branch in `.env`.
 *
 * The suite seeds a single host user, runs every test under a deterministic
 * AsyncLocalStorage frame (so `OutboxEventPublisher` doesn't WARN about a
 * missing context), and cleans up its outbox rows + the host user at the
 * end. The User cascade-deletes its events; outbox_events are independent
 * append-only rows and must be cleaned by aggregateId.
 *
 * Skipped when DATABASE_URL is unset so unit-only runs still pass — the CI
 * job's `services: postgres` ensures the var is present whenever this test
 * should actually execute.
 */
describe.skipIf(!dbUrl)('EventPrismaRepository (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let publisher: OutboxEventPublisher;
  let repo: EventPrismaRepository;
  let hostUserId: string;
  const trackedEventIds = new Set<string>();

  const venue = (): Venue =>
    Venue.create({ address: '18 Raffles Quay, Singapore', latitude: 1.2806, longitude: 103.8504 });

  const buildEvent = (overrides: { now?: Date; status?: 'draft' } = {}): Event => {
    const id = createId();
    trackedEventIds.add(id);
    const now = overrides.now ?? new Date();
    return Event.create({
      id,
      hostUserId,
      title: 'Hawker tour at Lau Pa Sat',
      description: 'Meet at the satay street entrance',
      venue: venue(),
      startsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
      endsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
      capacity: Capacity.create(6),
      category: EventCategory.create('food'),
      costSplit: 'own',
      approvalMode: 'manual',
      now,
    });
  };

  const persist = async (event: Event): Promise<void> => {
    await runWithContext({ requestId: createId(), actorUserId: hostUserId }, () =>
      unitOfWork.run(async (ctx) => {
        const pending = event.pullEvents();
        await repo.save(event, ctx);
        await publisher.publish(ctx, ...pending);
      }),
    );
  };

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    publisher = new OutboxEventPublisher();
    repo = new EventPrismaRepository(db);

    hostUserId = createId();
    await db.user.create({
      data: {
        id: hostUserId,
        email: `host-${hostUserId}@tri9.test`,
        displayName: 'TRI-9 Host',
      },
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;
    if (trackedEventIds.size > 0) {
      await db.outboxEvent.deleteMany({
        where: { aggregateType: 'Event', aggregateId: { in: [...trackedEventIds] } },
      });
    }
    await db.user.delete({ where: { id: hostUserId } }).catch(() => null);
    await db.$disconnect();
  });

  it('round-trips a saved draft event (save → findById)', async () => {
    const event = buildEvent();

    await persist(event);

    const loaded = await repo.findById(event.id);
    expect(loaded).not.toBeNull();
    if (!loaded) return;
    expect(loaded.id).toBe(event.id);
    expect(loaded.hostUserId).toBe(hostUserId);
    expect(loaded.title).toBe('Hawker tour at Lau Pa Sat');
    expect(loaded.description).toBe('Meet at the satay street entrance');
    expect(loaded.venue.address).toBe('18 Raffles Quay, Singapore');
    expect(loaded.venue.latitude).toBeCloseTo(1.2806, 4);
    expect(loaded.venue.longitude).toBeCloseTo(103.8504, 4);
    expect(loaded.capacity.value).toBe(6);
    expect(loaded.category.value).toBe('food');
    expect(loaded.costSplit).toBe('own');
    expect(loaded.approvalMode).toBe('manual');
    expect(loaded.status).toBe('draft');
    expect(loaded.cancellationReason).toBeNull();
  });

  it('writes an events.eventCreated row to the outbox atomically with the event row', async () => {
    const event = buildEvent();

    await persist(event);

    const outboxRows = await db.outboxEvent.findMany({
      where: { aggregateType: 'Event', aggregateId: event.id },
      orderBy: { seq: 'asc' },
    });
    expect(outboxRows).toHaveLength(1);
    expect(outboxRows[0]?.type).toBe(EVENT_CREATED);
  });

  it('persists subsequent state transitions (publish, cancel) and emits one event per transition', async () => {
    const event = buildEvent();
    await persist(event);

    const loadedDraft = await repo.findById(event.id);
    expect(loadedDraft?.status).toBe('draft');
    loadedDraft?.publish(new Date());
    if (loadedDraft) await persist(loadedDraft);

    const loadedPublished = await repo.findById(event.id);
    expect(loadedPublished?.status).toBe('published');
    loadedPublished?.cancel('weather', new Date());
    if (loadedPublished) await persist(loadedPublished);

    const loadedCancelled = await repo.findById(event.id);
    expect(loadedCancelled?.status).toBe('cancelled');
    expect(loadedCancelled?.cancellationReason).toBe('weather');

    const outboxRows = await db.outboxEvent.findMany({
      where: { aggregateType: 'Event', aggregateId: event.id },
      orderBy: { seq: 'asc' },
    });
    expect(outboxRows.map((r) => r.type)).toEqual([
      EVENT_CREATED,
      EVENT_PUBLISHED,
      EVENT_CANCELLED,
    ]);
  });

  it('returns null for an unknown id', async () => {
    expect(await repo.findById(createId())).toBeNull();
  });

  it('rejects saving an event whose host does not exist (FK guard)', async () => {
    const orphan = Event.create({
      id: createId(),
      hostUserId: createId(), // non-existent user
      title: 'Orphan event',
      description: null,
      venue: venue(),
      startsAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      endsAt: new Date(Date.now() + 24 * 60 * 60 * 1000 + 60 * 60 * 1000),
      capacity: Capacity.create(2),
      category: EventCategory.create('other'),
      costSplit: 'own',
      approvalMode: 'auto',
      now: new Date(),
    });
    // Pull events so the (failed) save doesn't leave them queued on the
    // aggregate — keeps the test hermetic if the assertion library decides
    // to inspect the value.
    orphan.pullEvents();
    await expect(repo.save(orphan)).rejects.toThrow();
  });
});
