import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Event } from '../../domain/entities/event.js';
import { EVENT_COVER_PHOTO_REPLACED } from '../../domain/events/event-cover-photo-replaced.event.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
import { VenueCategory } from '../../domain/value-objects/venue-category.js';
import { Venue } from '../../domain/value-objects/venue.js';
import { ReplaceCoverPhotoUseCase } from './replace-cover-photo.usecase.js';
import {
  FakeEventPublisher,
  FakeEventRepository,
  FakeFileStorage,
  FakeUnitOfWork,
  FixedClock,
} from './fakes.js';

const NOW = new Date('2026-06-01T00:00:00Z');
const HOST_ID = 'user_host_1';
const OTHER_ID = 'user_other_1';
const DEFAULT_MAX_BYTES = 5_242_880;

const buildSut = () => {
  const repo = new FakeEventRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const fileStorage = new FakeFileStorage();
  const useCase = new ReplaceCoverPhotoUseCase(
    uow,
    repo,
    publisher,
    clock,
    fileStorage,
    DEFAULT_MAX_BYTES,
  );
  return { repo, publisher, useCase, fileStorage };
};

const seedPublishedEvent = (repo: FakeEventRepository, hostUserId = HOST_ID): Event => {
  const event = Event.create({
    id: 'evt_1',
    hostUserId,
    title: 'Hawker tour at Lau Pa Sat',
    description: null,
    venue: Venue.create({
      address: '18 Raffles Quay',
      city: 'Singapore',
      latitude: 1,
      longitude: 1,
    }),
    startsAt: new Date(NOW.getTime() + 24 * 60 * 60 * 1000),
    endsAt: new Date(NOW.getTime() + 25 * 60 * 60 * 1000),
    capacity: Capacity.create(6),
    category: EventCategory.create('food'),
    venueCategory: VenueCategory.create('cafe'),
    costNotes: null,
    approvalMode: 'auto',
    now: NOW,
  });
  event.publish(new Date(NOW.getTime() + 500));
  event.pullEvents(); // drain so assertions below are clean
  repo.put(event);
  return event;
};

describe('ReplaceCoverPhotoUseCase', () => {
  it('returns 404-shape error when event does not exist', async () => {
    const { useCase } = buildSut();
    const err = await useCase
      .execute({
        eventId: 'missing',
        actorUserId: HOST_ID,
        coverPhotoStorageKey: `events/${HOST_ID}/new.jpg`,
      })
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AppError);
    expect((err as AppError).status).toBe(404);
  });

  // AC6: host-only enforced server-side
  it('throws 403 when the actor is not the host (AC6)', async () => {
    const { repo, useCase } = buildSut();
    seedPublishedEvent(repo);
    const err = await useCase
      .execute({
        eventId: 'evt_1',
        actorUserId: OTHER_ID,
        coverPhotoStorageKey: `events/${OTHER_ID}/new.jpg`,
      })
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AppError);
    expect((err as AppError).status).toBe(403);
    expect((err as AppError).message).toMatch(/host/);
  });

  it('throws 403 when coverPhotoStorageKey does not belong to the host (prefix mismatch)', async () => {
    const { repo, useCase } = buildSut();
    seedPublishedEvent(repo);
    const err = await useCase
      .execute({
        eventId: 'evt_1',
        actorUserId: HOST_ID,
        // Key scoped to a different user — cross-host injection attempt.
        coverPhotoStorageKey: `events/${OTHER_ID}/injected.jpg`,
      })
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AppError);
    expect((err as AppError).status).toBe(403);
  });

  it('happy path: persists new key and publishes eventCoverPhotoReplaced', async () => {
    const { repo, publisher, useCase, fileStorage } = buildSut();
    seedPublishedEvent(repo);
    const newKey = `events/${HOST_ID}/new-cover.jpg`;
    fileStorage.setSize(newKey, DEFAULT_MAX_BYTES);

    const result = await useCase.execute({
      eventId: 'evt_1',
      actorUserId: HOST_ID,
      coverPhotoStorageKey: newKey,
    });

    expect(result.coverPhotoStorageKey).toBe(newKey);
    expect(publisher.published).toHaveLength(1);
    expect(publisher.published[0]?.type).toBe(EVENT_COVER_PHOTO_REPLACED);
    expect(publisher.published[0]?.payload).toMatchObject({
      eventId: 'evt_1',
      hostUserId: HOST_ID,
      coverPhotoStorageKey: newKey,
    });
    // Persisted in repo
    const saved = await repo.findById('evt_1');
    expect(saved?.coverPhotoStorageKey).toBe(newKey);
  });

  it('no-op when the same key is supplied — no event published', async () => {
    const { repo, publisher, useCase, fileStorage } = buildSut();
    const existingKey = `events/${HOST_ID}/existing.jpg`;
    const event = seedPublishedEvent(repo);
    // Set the key via the domain method to pre-load it, then drain.
    event.setCoverPhoto(existingKey, new Date(NOW.getTime() + 100));
    event.pullEvents();
    repo.put(event);
    fileStorage.setSize(existingKey, DEFAULT_MAX_BYTES);

    const result = await useCase.execute({
      eventId: 'evt_1',
      actorUserId: HOST_ID,
      coverPhotoStorageKey: existingKey,
    });

    expect(publisher.published).toHaveLength(0);
    expect(result.coverPhotoStorageKey).toBe(existingKey);
  });

  // --- TRI-305: cover photo byte-cap enforcement ---

  it('throws 422 when cover photo exceeds byte cap (event unchanged, no event emitted)', async () => {
    const { repo, publisher, useCase, fileStorage } = buildSut();
    const originalKey = `events/${HOST_ID}/existing.jpg`;
    const event = seedPublishedEvent(repo);
    event.setCoverPhoto(originalKey, new Date(NOW.getTime() + 100));
    event.pullEvents();
    repo.put(event);

    const oversizedKey = `events/${HOST_ID}/too-big.jpg`;
    fileStorage.setSize(oversizedKey, DEFAULT_MAX_BYTES + 1);

    const err = await useCase
      .execute({
        eventId: 'evt_1',
        actorUserId: HOST_ID,
        coverPhotoStorageKey: oversizedKey,
      })
      .catch((e: unknown) => e);

    expect(err).toBeInstanceOf(AppError);
    const appErr = err as AppError;
    expect(appErr.status).toBe(422);
    expect(appErr.code).toBe('UNPROCESSABLE');
    const details = appErr.details as Record<string, unknown>;
    expect(details.subcode).toBe('COVER_PHOTO_TOO_LARGE');
    expect(details.maxBytes).toBe(DEFAULT_MAX_BYTES);
    expect(details.actualBytes).toBe(DEFAULT_MAX_BYTES + 1);

    expect(publisher.published).toHaveLength(0);
    const saved = await repo.findById('evt_1');
    expect(saved?.coverPhotoStorageKey).toBe(originalKey);
  });
});
