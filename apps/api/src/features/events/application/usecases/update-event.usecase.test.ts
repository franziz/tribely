import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Event } from '../../domain/entities/event.js';
import { EVENT_UPDATED } from '../../domain/events/event-updated.event.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
import { Venue } from '../../domain/value-objects/venue.js';
import { UpdateEventUseCase } from './update-event.usecase.js';
import {
  FakeEventPublisher,
  FakeEventRepository,
  FakeUnitOfWork,
  FixedClock,
} from './__test__/fakes.js';

const NOW = new Date('2026-05-11T00:00:00Z');

const buildSut = () => {
  const repo = new FakeEventRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new UpdateEventUseCase(uow, repo, publisher, clock);
  return { repo, publisher, clock, useCase };
};

const seedDraft = (repo: FakeEventRepository, hostUserId = 'user_1'): Event => {
  const event = Event.create({
    id: 'evt_1',
    hostUserId,
    title: 'Original',
    description: null,
    venue: Venue.create({ address: 'X', city: 'Singapore', latitude: 1, longitude: 1 }),
    startsAt: new Date(NOW.getTime() + 24 * 60 * 60 * 1000),
    endsAt: new Date(NOW.getTime() + 25 * 60 * 60 * 1000),
    capacity: Capacity.create(4),
    category: EventCategory.create('food'),
    costSplit: 'own',
    approvalMode: 'auto',
    now: NOW,
  });
  event.pullEvents();
  repo.put(event);
  return event;
};

describe('UpdateEventUseCase', () => {
  it('applies the patch and emits eventUpdated', async () => {
    const { repo, publisher, useCase } = buildSut();
    seedDraft(repo);

    const result = await useCase.execute({
      eventId: 'evt_1',
      actorUserId: 'user_1',
      patch: { title: 'New Title', capacity: 10 },
    });

    expect(result.title).toBe('New Title');
    expect(result.capacity.value).toBe(10);
    expect(publisher.published.map((e) => e.type)).toEqual([EVENT_UPDATED]);
  });

  it('rejects edits by anyone other than the host', async () => {
    const { repo, useCase } = buildSut();
    seedDraft(repo);
    await expect(
      useCase.execute({
        eventId: 'evt_1',
        actorUserId: 'someone-else',
        patch: { title: 'Hacked' },
      }),
    ).rejects.toThrowError(/host/);
  });

  it('returns 404-shape error when event does not exist', async () => {
    const { useCase } = buildSut();
    await expect(
      useCase.execute({ eventId: 'missing', actorUserId: 'user_1', patch: { title: 'x' } }),
    ).rejects.toThrowError(AppError);
  });

  it('does NOT publish anything when patch is a no-op', async () => {
    const { repo, publisher, useCase } = buildSut();
    const seeded = seedDraft(repo);
    await useCase.execute({
      eventId: seeded.id,
      actorUserId: 'user_1',
      patch: { title: seeded.title },
    });
    expect(publisher.published).toHaveLength(0);
  });

  it('refuses to edit a cancelled event', async () => {
    const { repo, useCase } = buildSut();
    const seeded = seedDraft(repo);
    seeded.cancel('weather', new Date(NOW.getTime() + 1000));
    seeded.pullEvents();
    await expect(
      useCase.execute({
        eventId: seeded.id,
        actorUserId: 'user_1',
        patch: { title: 'new' },
      }),
    ).rejects.toThrowError(/Cannot edit/);
  });
});
