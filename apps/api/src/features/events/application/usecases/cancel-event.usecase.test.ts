import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Event } from '../../domain/entities/event.js';
import { EVENT_CANCELLED } from '../../domain/events/event-cancelled.event.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
import { VenueCategory } from '../../domain/value-objects/venue-category.js';
import { Venue } from '../../domain/value-objects/venue.js';
import { CancelEventUseCase } from './cancel-event.usecase.js';
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
  const useCase = new CancelEventUseCase(uow, repo, publisher, clock);
  return { repo, publisher, useCase };
};

const seedDraft = (repo: FakeEventRepository): Event => {
  const event = Event.create({
    id: 'evt_1',
    hostUserId: 'user_1',
    title: 'A thing',
    description: null,
    venue: Venue.create({ address: 'X', city: 'Singapore', latitude: 1, longitude: 1 }),
    startsAt: new Date(NOW.getTime() + 24 * 60 * 60 * 1000),
    endsAt: new Date(NOW.getTime() + 25 * 60 * 60 * 1000),
    capacity: Capacity.create(4),
    category: EventCategory.create('food'),
    venueCategory: VenueCategory.create('cafe'),
    costSplit: 'own',
    approvalMode: 'auto',
    now: NOW,
  });
  event.pullEvents();
  repo.put(event);
  return event;
};

describe('CancelEventUseCase', () => {
  it('cancels with the supplied reason and emits eventCancelled', async () => {
    const { repo, publisher, useCase } = buildSut();
    seedDraft(repo);

    await useCase.execute({ eventId: 'evt_1', actorUserId: 'user_1', reason: 'weather' });

    const stored = await repo.findById('evt_1');
    expect(stored?.status).toBe('cancelled');
    expect(stored?.cancellationReason).toBe('weather');
    expect(publisher.published.map((e) => e.type)).toEqual([EVENT_CANCELLED]);
  });

  it('falls back to the default reason when none is supplied', async () => {
    const { repo, useCase } = buildSut();
    seedDraft(repo);

    await useCase.execute({ eventId: 'evt_1', actorUserId: 'user_1', reason: null });

    const stored = await repo.findById('evt_1');
    expect(stored?.cancellationReason).toBe('Cancelled by host');
  });

  it('falls back when reason is whitespace-only', async () => {
    const { repo, useCase } = buildSut();
    seedDraft(repo);

    await useCase.execute({ eventId: 'evt_1', actorUserId: 'user_1', reason: '   ' });

    const stored = await repo.findById('evt_1');
    expect(stored?.cancellationReason).toBe('Cancelled by host');
  });

  it('rejects cancellation by a non-host', async () => {
    const { repo, useCase } = buildSut();
    seedDraft(repo);
    await expect(
      useCase.execute({ eventId: 'evt_1', actorUserId: 'someone-else', reason: null }),
    ).rejects.toThrowError(/host/);
  });

  it('is idempotent on a second cancel call (no extra event emitted)', async () => {
    const { repo, publisher, useCase } = buildSut();
    seedDraft(repo);
    await useCase.execute({ eventId: 'evt_1', actorUserId: 'user_1', reason: 'weather' });
    await useCase.execute({ eventId: 'evt_1', actorUserId: 'user_1', reason: 'again' });
    expect(publisher.published.map((e) => e.type)).toEqual([EVENT_CANCELLED]);
  });

  it('returns 404-shape error when the event does not exist', async () => {
    const { useCase } = buildSut();
    await expect(
      useCase.execute({ eventId: 'missing', actorUserId: 'user_1', reason: null }),
    ).rejects.toThrowError(AppError);
  });
});
