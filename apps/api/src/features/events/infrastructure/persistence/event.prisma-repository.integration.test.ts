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
import { VenueCategory } from '../../domain/value-objects/venue-category.js';
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

  const venue = (city = 'Singapore'): Venue =>
    Venue.create({
      address: '18 Raffles Quay, Singapore',
      city,
      latitude: 1.2806,
      longitude: 103.8504,
    });

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
      venueCategory: VenueCategory.create('cafe'),
      costNotes: null,
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
    expect(loaded.venue.city).toBe('Singapore');
    expect(loaded.venue.latitude).toBeCloseTo(1.2806, 4);
    expect(loaded.venue.longitude).toBeCloseTo(103.8504, 4);
    expect(loaded.capacity.value).toBe(6);
    expect(loaded.category.value).toBe('food');
    expect(loaded.costNotes).toBeNull();
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

  it('accepts saving an event with a non-existent hostUserId (FK intentionally absent — TRI-134 pseudonymisation)', async () => {
    // The events_hostUserId_fkey FK was dropped in migration
    // tri134_drop_event_host_and_jr_requester_fks so pseudonymised rows can
    // carry a cuid2 with no corresponding User row. This test verifies the FK
    // is gone and the save succeeds (previously this test asserted rejection).
    const pseudonymId = createId();
    const orphan = Event.create({
      id: createId(),
      hostUserId: pseudonymId, // no User row for this id
      title: 'Orphan event post-pseudonymisation',
      description: null,
      venue: venue(),
      startsAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      endsAt: new Date(Date.now() + 24 * 60 * 60 * 1000 + 60 * 60 * 1000),
      capacity: Capacity.create(2),
      category: EventCategory.create('other'),
      venueCategory: VenueCategory.create('cafe'),
      costNotes: null,
      approvalMode: 'auto',
      now: new Date(),
    });
    orphan.pullEvents();
    await expect(repo.save(orphan)).resolves.toBeUndefined();
    // Clean up: delete the orphan row (no user to cascade-delete it).
    await db.event.delete({ where: { id: orphan.id } }).catch(() => null);
  });

  describe('pseudonymiseHostForUser', () => {
    it('rewrites hostUserId for matched rows, leaves other users untouched, returns correct count', async () => {
      // Seed: 3 users × 2 events each. Pseudonymise user A only.
      const userA = createId();
      const userB = createId();
      const userC = createId();
      await db.user.createMany({
        data: [
          { id: userA, email: `pseudo-a-${userA}@tri134.test`, displayName: 'PseudoA' },
          { id: userB, email: `pseudo-b-${userB}@tri134.test`, displayName: 'PseudoB' },
          { id: userC, email: `pseudo-c-${userC}@tri134.test`, displayName: 'PseudoC' },
        ],
      });

      const now = new Date();
      const makeEventData = (id: string, hid: string) => ({
        id,
        hostUserId: hid,
        title: 'Pseudonymise test',
        description: null,
        venueAddress: '1 Raffles Pl',
        venueCity: 'Singapore',
        venueLatitude: 1.28,
        venueLongitude: 103.85,
        startsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
        endsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000 + 2 * 60 * 60 * 1000),
        capacity: 4,
        category: 'food',
        costNotes: null,
        approvalMode: 'manual',
        status: 'draft',
        cancellationReason: null,
        createdAt: now,
        updatedAt: now,
      });

      const aId1 = createId();
      const aId2 = createId();
      const bId1 = createId();
      const bId2 = createId();
      const cId1 = createId();
      const aIds = [aId1, aId2];
      const bIds = [bId1, bId2];
      const cIds = [cId1];
      await db.event.createMany({
        data: [
          makeEventData(aId1, userA),
          makeEventData(aId2, userA),
          makeEventData(bId1, userB),
          makeEventData(bId2, userB),
          makeEventData(cId1, userC),
        ],
      });

      try {
        const pseudonym = createId();
        const count = await runWithContext({ requestId: createId(), actorUserId: userA }, () =>
          unitOfWork.run(async (ctx) => repo.pseudonymiseHostForUser(userA, pseudonym, ctx)),
        );

        expect(count).toBe(2);

        // User A rows rewritten to pseudonym.
        const aRows = await db.event.findMany({ where: { id: { in: aIds } } });
        expect(aRows.every((r) => r.hostUserId === pseudonym)).toBe(true);

        // User B and C rows untouched.
        const bRows = await db.event.findMany({ where: { id: { in: bIds } } });
        expect(bRows.every((r) => r.hostUserId === userB)).toBe(true);
        const cRows = await db.event.findMany({ where: { id: { in: cIds } } });
        expect(cRows.every((r) => r.hostUserId === userC)).toBe(true);
      } finally {
        await db.event.deleteMany({
          where: { id: { in: [...aIds, ...bIds, ...cIds] } },
        });
        await db.user.deleteMany({ where: { id: { in: [userA, userB, userC] } } });
      }
    });

    it('returns 0 when no rows match the userId', async () => {
      const count = await runWithContext({ requestId: createId(), actorUserId: createId() }, () =>
        unitOfWork.run(async (ctx) => repo.pseudonymiseHostForUser(createId(), createId(), ctx)),
      );
      expect(count).toBe(0);
    });
  });

  describe('findManyForListing', () => {
    // Build a published event at a deterministic startsAt offset so listing
    // assertions can rely on ordering.
    const buildPublished = async (overrides: {
      startsAt: Date;
      city?: string;
      category?: 'food' | 'drinks' | 'hike';
    }): Promise<Event> => {
      const id = createId();
      trackedEventIds.add(id);
      const now = new Date(overrides.startsAt.getTime() - 7 * 24 * 60 * 60 * 1000);
      const event = Event.create({
        id,
        hostUserId,
        title: 'Listing test event',
        description: null,
        venue: venue(overrides.city ?? 'Singapore'),
        startsAt: overrides.startsAt,
        endsAt: new Date(overrides.startsAt.getTime() + 2 * 60 * 60 * 1000),
        capacity: Capacity.create(6),
        category: EventCategory.create(overrides.category ?? 'food'),
        venueCategory: VenueCategory.create('cafe'),
        costNotes: null,
        approvalMode: 'manual',
        now,
      });
      event.publish(now);
      await persist(event);
      return event;
    };

    it('returns published events ordered by startsAt asc, filtered to endsAt > now', async () => {
      const base = Date.now();
      const past = await buildPublished({ startsAt: new Date(base - 2 * 60 * 60 * 1000) });
      // `past` has endsAt = startsAt + 2h, which is `base` — still > now if we
      // advance the filter `now` past base. Use a `now` beyond past.endsAt to
      // exclude it.
      const future1 = await buildPublished({ startsAt: new Date(base + 1 * 24 * 60 * 60 * 1000) });
      const future2 = await buildPublished({ startsAt: new Date(base + 2 * 24 * 60 * 60 * 1000) });

      const page = await repo.findManyForListing(
        { now: new Date(past.endsAt.getTime() + 1000), hostUserId },
        null,
        50,
      );
      const ids = page.events.map((e) => e.id);
      expect(ids).toContain(future1.id);
      expect(ids).toContain(future2.id);
      expect(ids).not.toContain(past.id);
      // Relative order between the two future events: ascending by startsAt.
      expect(ids.indexOf(future1.id)).toBeLessThan(ids.indexOf(future2.id));
    });

    it('filters by city, category, and time window', async () => {
      const base = Date.now();
      const sgFood = await buildPublished({
        startsAt: new Date(base + 3 * 24 * 60 * 60 * 1000),
        city: 'Singapore',
        category: 'food',
      });
      const sgDrinks = await buildPublished({
        startsAt: new Date(base + 3 * 24 * 60 * 60 * 1000 + 60 * 60 * 1000),
        city: 'Singapore',
        category: 'drinks',
      });
      const jktFood = await buildPublished({
        startsAt: new Date(base + 3 * 24 * 60 * 60 * 1000 + 2 * 60 * 60 * 1000),
        city: 'Jakarta',
        category: 'food',
      });

      const cityOnly = await repo.findManyForListing(
        { now: new Date(base), city: 'Singapore', hostUserId },
        null,
        50,
      );
      const cityIds = cityOnly.events.map((e) => e.id);
      expect(cityIds).toContain(sgFood.id);
      expect(cityIds).toContain(sgDrinks.id);
      expect(cityIds).not.toContain(jktFood.id);

      const cityAndCategory = await repo.findManyForListing(
        { now: new Date(base), city: 'Singapore', category: 'food', hostUserId },
        null,
        50,
      );
      const ccIds = cityAndCategory.events.map((e) => e.id);
      expect(ccIds).toContain(sgFood.id);
      expect(ccIds).not.toContain(sgDrinks.id);

      const windowed = await repo.findManyForListing(
        {
          now: new Date(base),
          from: sgFood.startsAt,
          to: sgDrinks.startsAt,
          hostUserId,
        },
        null,
        50,
      );
      const windowedIds = windowed.events.map((e) => e.id);
      expect(windowedIds).toContain(sgFood.id);
      expect(windowedIds).toContain(sgDrinks.id);
      expect(windowedIds).not.toContain(jktFood.id);
    });

    it('paginates with keyset cursor (last row of page 1 = predicate for page 2)', async () => {
      const base = Date.now();
      // Use a distinctive city so the assertions ignore noise from siblings.
      const city = `Cursor-${createId().slice(0, 6)}`;
      const created = await Promise.all(
        [0, 1, 2, 3, 4].map((i) =>
          buildPublished({
            startsAt: new Date(base + (10 + i) * 24 * 60 * 60 * 1000),
            city,
          }),
        ),
      );

      const page1 = await repo.findManyForListing({ now: new Date(base), city }, null, 2);
      expect(page1.events).toHaveLength(2);
      expect(page1.nextCursor).not.toBeNull();
      expect(page1.events[0]?.id).toBe(created[0]?.id);
      expect(page1.events[1]?.id).toBe(created[1]?.id);

      const page2 = await repo.findManyForListing(
        { now: new Date(base), city },
        page1.nextCursor,
        2,
      );
      expect(page2.events).toHaveLength(2);
      expect(page2.events[0]?.id).toBe(created[2]?.id);
      expect(page2.events[1]?.id).toBe(created[3]?.id);

      const page3 = await repo.findManyForListing(
        { now: new Date(base), city },
        page2.nextCursor,
        2,
      );
      expect(page3.events).toHaveLength(1);
      expect(page3.events[0]?.id).toBe(created[4]?.id);
      expect(page3.nextCursor).toBeNull();
    });
  });
});
