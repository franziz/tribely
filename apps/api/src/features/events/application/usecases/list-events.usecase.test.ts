import { describe, expect, it } from 'vitest';
import { Event } from '../../domain/entities/event.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
import { VenueCategory } from '../../domain/value-objects/venue-category.js';
import { Venue } from '../../domain/value-objects/venue.js';
import { ListEventsUseCase } from './list-events.usecase.js';
import { FakeEventRepository, FixedClock } from './fakes.js';

const NOW = new Date('2026-05-11T00:00:00Z');

const buildPublished = (overrides: {
  id: string;
  startsAt: Date;
  city?: string;
  category?: 'food' | 'drinks';
  hostUserId?: string;
}): Event => {
  const creationNow = new Date(overrides.startsAt.getTime() - 24 * 60 * 60 * 1000);
  const event = Event.create({
    id: overrides.id,
    hostUserId: overrides.hostUserId ?? 'user_1',
    title: 'List me',
    description: null,
    venue: Venue.create({
      address: 'X',
      city: overrides.city ?? 'Singapore',
      latitude: 1,
      longitude: 1,
    }),
    startsAt: overrides.startsAt,
    endsAt: new Date(overrides.startsAt.getTime() + 60 * 60 * 1000),
    capacity: Capacity.create(4),
    category: EventCategory.create(overrides.category ?? 'food'),
    venueCategory: VenueCategory.create('cafe'),
    costSplit: 'own',
    approvalMode: 'auto',
    now: creationNow,
  });
  event.publish(creationNow);
  event.pullEvents();
  return event;
};

const buildSut = () => {
  const repo = new FakeEventRepository();
  const clock = new FixedClock(NOW);
  const useCase = new ListEventsUseCase(repo, clock);
  return { repo, clock, useCase };
};

describe('ListEventsUseCase', () => {
  it('returns published events filtered by city + category', async () => {
    const { repo, useCase } = buildSut();
    repo.put(
      buildPublished({
        id: 'a',
        startsAt: new Date(NOW.getTime() + 24 * 60 * 60 * 1000),
        city: 'Singapore',
        category: 'food',
      }),
    );
    repo.put(
      buildPublished({
        id: 'b',
        startsAt: new Date(NOW.getTime() + 25 * 60 * 60 * 1000),
        city: 'Jakarta',
        category: 'food',
      }),
    );
    repo.put(
      buildPublished({
        id: 'c',
        startsAt: new Date(NOW.getTime() + 26 * 60 * 60 * 1000),
        city: 'Singapore',
        category: 'drinks',
      }),
    );

    const page = await useCase.execute({ city: 'Singapore', category: 'food', limit: 50 });
    expect(page.events.map((e) => e.id)).toEqual(['a']);
    expect(page.nextCursor).toBeNull();
  });

  it('filters by hostUserId — returns only events for that host', async () => {
    const { repo, useCase } = buildSut();
    repo.put(
      buildPublished({
        id: 'a',
        startsAt: new Date(NOW.getTime() + 24 * 60 * 60 * 1000),
        hostUserId: 'host_a',
      }),
    );
    repo.put(
      buildPublished({
        id: 'b',
        startsAt: new Date(NOW.getTime() + 25 * 60 * 60 * 1000),
        hostUserId: 'host_b',
      }),
    );

    const page = await useCase.execute({ hostUserId: 'host_a', limit: 50 });
    expect(page.events.map((e) => e.id)).toEqual(['a']);
  });

  it('hostUserId filter returns empty list when host has no events', async () => {
    const { repo, useCase } = buildSut();
    repo.put(
      buildPublished({
        id: 'a',
        startsAt: new Date(NOW.getTime() + 24 * 60 * 60 * 1000),
        hostUserId: 'host_a',
      }),
    );

    const page = await useCase.execute({ hostUserId: 'no_such_host', limit: 50 });
    expect(page.events).toHaveLength(0);
  });

  it('paginates with a cursor', async () => {
    const { repo, useCase } = buildSut();
    repo.put(buildPublished({ id: 'a', startsAt: new Date(NOW.getTime() + 1 * 60 * 60 * 1000) }));
    repo.put(buildPublished({ id: 'b', startsAt: new Date(NOW.getTime() + 2 * 60 * 60 * 1000) }));
    repo.put(buildPublished({ id: 'c', startsAt: new Date(NOW.getTime() + 3 * 60 * 60 * 1000) }));

    const p1 = await useCase.execute({ limit: 2 });
    expect(p1.events.map((e) => e.id)).toEqual(['a', 'b']);
    expect(p1.nextCursor).not.toBeNull();

    const cursor = p1.nextCursor;
    if (!cursor) throw new Error('expected cursor');
    const p2 = await useCase.execute({ limit: 2, cursor });
    expect(p2.events.map((e) => e.id)).toEqual(['c']);
    expect(p2.nextCursor).toBeNull();
  });
});
