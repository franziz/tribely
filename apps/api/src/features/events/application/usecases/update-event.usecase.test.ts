import { describe, expect, it, vi } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Event } from '../../domain/entities/event.js';
import { EVENT_UPDATED } from '../../domain/events/event-updated.event.js';
import { PRIVATE_VENUE_ATTEMPTED } from '../../domain/events/private-venue-attempted.event.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
import { VenueCategory } from '../../domain/value-objects/venue-category.js';
import { Venue } from '../../domain/value-objects/venue.js';
import { UpdateEventUseCase } from './update-event.usecase.js';
import {
  FakeEventPublisher,
  FakeEventRepository,
  FakeGetUserCapabilitiesUseCase,
  FakeUnitOfWork,
  FixedClock,
} from './fakes.js';

const NOW = new Date('2026-05-11T00:00:00Z');

const buildSut = (canPostPrivateVenue = true) => {
  const repo = new FakeEventRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const fakeCapabilities = new FakeGetUserCapabilitiesUseCase();
  fakeCapabilities.setCanPostPrivateVenue(canPostPrivateVenue);
  const useCase = new UpdateEventUseCase(uow, repo, publisher, clock, fakeCapabilities);
  return { repo, publisher, clock, useCase, fakeCapabilities };
};

const seedDraft = (repo: FakeEventRepository, hostUserId = 'user_1', venueCat = 'cafe'): Event => {
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
    venueCategory: VenueCategory.create(venueCat),
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

  // --- TRI-33: public-venue enforcement on update ---

  it('host patches venue to private category + first-time host → 422, rejection event published, no eventUpdated', async () => {
    const { repo, publisher, useCase } = buildSut(false);
    seedDraft(repo, 'user_1', 'cafe');

    const err = await useCase
      .execute({
        eventId: 'evt_1',
        actorUserId: 'user_1',
        patch: { venueCategory: 'apartment' },
      })
      .catch((e: unknown) => e);

    expect(err).toBeInstanceOf(AppError);
    const appErr = err as AppError;
    expect(appErr.status).toBe(422);
    expect(appErr.code).toBe('UNPROCESSABLE');
    expect((appErr.details as Record<string, unknown>).subcode).toBe('FIRST_EVENT_MUST_BE_PUBLIC');

    const types = publisher.published.map((e) => e.type);
    expect(types).toContain(PRIVATE_VENUE_ATTEMPTED);
    expect(types).not.toContain(EVENT_UPDATED);

    // Original event row must be unchanged
    expect(repo.all()[0]?.venueCategory.value).toBe('cafe');
  });

  it('host patches venue to private category + established host → success, eventUpdated emitted, no rejection event', async () => {
    const { repo, publisher, useCase } = buildSut(true);
    seedDraft(repo, 'user_1', 'cafe');

    const result = await useCase.execute({
      eventId: 'evt_1',
      actorUserId: 'user_1',
      patch: { venueCategory: 'apartment' },
    });

    expect(result.venueCategory.value).toBe('apartment');
    const types = publisher.published.map((e) => e.type);
    expect(types).toContain(EVENT_UPDATED);
    expect(types).not.toContain(PRIVATE_VENUE_ATTEMPTED);
    expect(repo.all()[0]?.venueCategory.value).toBe('apartment');
  });

  it('title-only patch + first-time host → success without calling getUserCapabilities', async () => {
    const { repo, useCase, fakeCapabilities } = buildSut(false);
    seedDraft(repo, 'user_1', 'cafe');

    const executeSpy = vi.spyOn(fakeCapabilities, 'execute');

    const result = await useCase.execute({
      eventId: 'evt_1',
      actorUserId: 'user_1',
      patch: { title: 'A brand new title' },
    });

    expect(result.title).toBe('A brand new title');
    expect(executeSpy).not.toHaveBeenCalled();
  });

  it('title-only patch on a private-category grandfathered event + first-time host → success (no retro-enforcement)', async () => {
    const { repo, useCase, fakeCapabilities } = buildSut(false);
    // Seed with a private category (simulates a grandfathered / backfilled row)
    seedDraft(repo, 'user_1', 'other');

    const executeSpy = vi.spyOn(fakeCapabilities, 'execute');

    const result = await useCase.execute({
      eventId: 'evt_1',
      actorUserId: 'user_1',
      patch: { title: 'Updated title' },
    });

    expect(result.title).toBe('Updated title');
    expect(executeSpy).not.toHaveBeenCalled();
  });

  it('patch venue.address containing "apartment" without changing category → 422 if first-time host', async () => {
    const { repo, publisher, useCase } = buildSut(false);
    seedDraft(repo, 'user_1', 'cafe');

    const err = await useCase
      .execute({
        eventId: 'evt_1',
        actorUserId: 'user_1',
        patch: {
          venue: {
            address: 'Apartment 12B Orchard Road',
            city: 'Singapore',
            latitude: 1,
            longitude: 1,
          },
        },
      })
      .catch((e: unknown) => e);

    expect(err).toBeInstanceOf(AppError);
    const appErr = err as AppError;
    expect(appErr.status).toBe(422);
    expect((appErr.details as Record<string, unknown>).reason).toBe('keyword_match');

    const types = publisher.published.map((e) => e.type);
    expect(types).toContain(PRIVATE_VENUE_ATTEMPTED);
    expect(types).not.toContain(EVENT_UPDATED);
  });
});
