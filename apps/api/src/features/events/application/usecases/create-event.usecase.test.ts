import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { EVENT_CREATED } from '../../domain/events/event-created.event.js';
import { EVENT_PUBLISHED } from '../../domain/events/event-published.event.js';
import {
  PRIVATE_VENUE_ATTEMPTED,
  type PrivateVenueAttemptedEvent,
} from '../../domain/events/private-venue-attempted.event.js';
import { CreateEventUseCase, type CreateEventInput } from './create-event.usecase.js';
import {
  FakeEventPublisher,
  FakeEventRepository,
  FakeFileStorage,
  FakeGetUserCapabilitiesUseCase,
  FakeUnitOfWork,
  FixedClock,
} from './fakes.js';

const NOW = new Date('2026-05-11T00:00:00Z');

const baseInput: CreateEventInput = {
  hostUserId: 'user_1',
  title: 'Hawker tour',
  description: 'Meet at the satay street entrance',
  venue: {
    address: '18 Raffles Quay',
    city: 'Singapore',
    latitude: 1.2806,
    longitude: 103.8504,
  },
  startsAt: new Date(NOW.getTime() + 7 * 24 * 60 * 60 * 1000),
  endsAt: new Date(NOW.getTime() + 7 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
  capacity: 6,
  category: 'food',
  venueCategory: 'cafe',
  costNotes: null,
  coverPhotoStorageKey: null,
  approvalMode: 'manual',
};

const DEFAULT_MAX_BYTES = 5_242_880;

const buildSut = (canPostPrivateVenue = false) => {
  const repo = new FakeEventRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const fakeCapabilities = new FakeGetUserCapabilitiesUseCase();
  fakeCapabilities.setCanPostPrivateVenue(canPostPrivateVenue);
  const fileStorage = new FakeFileStorage();
  const useCase = new CreateEventUseCase(
    uow,
    repo,
    publisher,
    clock,
    fakeCapabilities,
    fileStorage,
    DEFAULT_MAX_BYTES,
  );
  return { repo, publisher, clock, useCase, fakeCapabilities, fileStorage };
};

describe('CreateEventUseCase', () => {
  it('persists a published event and emits eventCreated + eventPublished', async () => {
    const { repo, publisher, useCase } = buildSut(true);
    const event = await useCase.execute(baseInput);

    expect(event.status).toBe('published');
    expect(event.hostUserId).toBe('user_1');
    expect(event.venue.city).toBe('Singapore');

    expect(repo.all()).toHaveLength(1);
    expect(publisher.published.map((e) => e.type)).toEqual([EVENT_CREATED, EVENT_PUBLISHED]);
  });

  it('rejects an event whose startsAt is in the past', async () => {
    const { useCase } = buildSut(true);
    await expect(
      useCase.execute({ ...baseInput, startsAt: new Date(NOW.getTime() - 1000) }),
    ).rejects.toThrowError(AppError);
  });

  it('rejects an invalid category', async () => {
    const { useCase } = buildSut(true);
    await expect(useCase.execute({ ...baseInput, category: 'nope' })).rejects.toThrowError(
      /category/,
    );
  });

  it('rejects a capacity below the minimum', async () => {
    const { useCase } = buildSut(true);
    await expect(useCase.execute({ ...baseInput, capacity: 1 })).rejects.toThrowError(/Capacity/);
  });

  // --- TRI-33: public-venue enforcement ---

  it('first-time host with public category and clean name → success, no rejection event', async () => {
    // caps=false (first-time host), but venue is public category + no keywords
    const { repo, publisher, useCase } = buildSut(false);
    const event = await useCase.execute({
      ...baseInput,
      venueCategory: 'cafe',
      venue: { ...baseInput.venue, address: '18 Raffles Quay' },
    });

    expect(event.status).toBe('published');
    expect(repo.all()).toHaveLength(1);
    const types = publisher.published.map((e) => e.type);
    expect(types).toContain(EVENT_CREATED);
    expect(types).toContain(EVENT_PUBLISHED);
    expect(types).not.toContain(PRIVATE_VENUE_ATTEMPTED);
  });

  it('first-time host + category=apartment → 422 UNPROCESSABLE, rejection event published, no eventCreated', async () => {
    const { repo, publisher, useCase } = buildSut(false);

    const err = await useCase
      .execute({ ...baseInput, venueCategory: 'apartment' })
      .catch((e: unknown) => e);

    expect(err).toBeInstanceOf(AppError);
    const appErr = err as AppError;
    expect(appErr.status).toBe(422);
    expect(appErr.code).toBe('UNPROCESSABLE');
    expect((appErr.details as Record<string, unknown>).subcode).toBe('FIRST_EVENT_MUST_BE_PUBLIC');
    expect((appErr.details as Record<string, unknown>).reason).toBe('category_not_public');

    const types = publisher.published.map((e) => e.type);
    expect(types).toContain(PRIVATE_VENUE_ATTEMPTED);
    expect(types).not.toContain(EVENT_CREATED);
    expect(repo.all()).toHaveLength(0);

    // matchedKeyword must be null for category rejections
    const rejectionEvent = publisher.published.find((e) => e.type === PRIVATE_VENUE_ATTEMPTED) as
      | PrivateVenueAttemptedEvent
      | undefined;
    expect(rejectionEvent?.payload.matchedKeyword).toBeNull();
  });

  it('first-time host + public category + name contains "apartment" → 422 with keyword_match reason', async () => {
    const { repo, publisher, useCase } = buildSut(false);

    const err = await useCase
      .execute({
        ...baseInput,
        venueCategory: 'cafe',
        venue: { ...baseInput.venue, address: 'My Apartment Coffee' },
      })
      .catch((e: unknown) => e);

    expect(err).toBeInstanceOf(AppError);
    const appErr = err as AppError;
    expect(appErr.status).toBe(422);
    expect((appErr.details as Record<string, unknown>).reason).toBe('keyword_match');

    const types = publisher.published.map((e) => e.type);
    expect(types).toContain(PRIVATE_VENUE_ATTEMPTED);
    expect(types).not.toContain(EVENT_CREATED);
    expect(repo.all()).toHaveLength(0);

    const rejectionEvent = publisher.published.find((e) => e.type === PRIVATE_VENUE_ATTEMPTED) as
      | PrivateVenueAttemptedEvent
      | undefined;
    expect(rejectionEvent?.payload.matchedKeyword).toBe('apartment');
  });

  it('established host (caps=true) + category=apartment → success, no rejection event', async () => {
    const { repo, publisher, useCase } = buildSut(true);
    const event = await useCase.execute({ ...baseInput, venueCategory: 'apartment' });

    expect(event.status).toBe('published');
    expect(repo.all()).toHaveLength(1);
    const types = publisher.published.map((e) => e.type);
    expect(types).not.toContain(PRIVATE_VENUE_ATTEMPTED);
    expect(types).toContain(EVENT_CREATED);
  });

  it('invalid venueCategory → 400 VALIDATION_ERROR, no rejection event published', async () => {
    const { publisher, useCase } = buildSut(false);

    const err = await useCase
      .execute({ ...baseInput, venueCategory: 'xyz' })
      .catch((e: unknown) => e);

    expect(err).toBeInstanceOf(AppError);
    const appErr = err as AppError;
    expect(appErr.status).toBe(400);
    expect(appErr.code).toBe('VALIDATION_ERROR');
    expect(publisher.published.map((e) => e.type)).not.toContain(PRIVATE_VENUE_ATTEMPTED);
  });

  // --- TRI-49: coverPhotoStorageKey ownership guard ---

  it('null coverPhotoStorageKey → no guard, event created successfully', async () => {
    const { repo, useCase } = buildSut(true);
    const event = await useCase.execute({ ...baseInput, coverPhotoStorageKey: null });

    expect(event.coverPhotoStorageKey).toBeNull();
    expect(repo.all()).toHaveLength(1);
  });

  it('own-prefixed coverPhotoStorageKey → passes guard, stored on event', async () => {
    const { repo, fileStorage, useCase } = buildSut(true);
    const ownKey = `events/${baseInput.hostUserId}/someimage.jpg`;
    fileStorage.setSize(ownKey, 1);
    const event = await useCase.execute({ ...baseInput, coverPhotoStorageKey: ownKey });

    expect(event.coverPhotoStorageKey).toBe(ownKey);
    expect(repo.all()).toHaveLength(1);
  });

  it('foreign-prefix coverPhotoStorageKey → 403 FORBIDDEN, nothing persisted', async () => {
    const { repo, publisher, useCase } = buildSut(true);
    const foreignKey = 'events/other_user/photo.jpg';

    const err = await useCase
      .execute({ ...baseInput, coverPhotoStorageKey: foreignKey })
      .catch((e: unknown) => e);

    expect(err).toBeInstanceOf(AppError);
    const appErr = err as AppError;
    expect(appErr.status).toBe(403);
    expect(appErr.code).toBe('FORBIDDEN');
    // Nothing must be persisted — guard fires before Event.create
    expect(repo.all()).toHaveLength(0);
    expect(publisher.published).toHaveLength(0);
  });

  it('avatars/-prefix coverPhotoStorageKey (wrong path family) → 403 FORBIDDEN', async () => {
    const { useCase } = buildSut(true);
    const wrongPrefixKey = `avatars/${baseInput.hostUserId}/photo.jpg`;

    const err = await useCase
      .execute({ ...baseInput, coverPhotoStorageKey: wrongPrefixKey })
      .catch((e: unknown) => e);

    expect(err).toBeInstanceOf(AppError);
    expect((err as AppError).status).toBe(403);
  });

  // --- TRI-305: cover photo byte-cap enforcement ---

  it('cover photo within the byte cap → event created successfully', async () => {
    const { repo, fileStorage, useCase } = buildSut(true);
    const key = `events/${baseInput.hostUserId}/cover.jpg`;
    fileStorage.setSize(key, DEFAULT_MAX_BYTES);

    const event = await useCase.execute({ ...baseInput, coverPhotoStorageKey: key });

    expect(event.coverPhotoStorageKey).toBe(key);
    expect(repo.all()).toHaveLength(1);
  });

  it('cover photo exactly at the byte cap → event created successfully', async () => {
    const { repo, fileStorage, useCase } = buildSut(true);
    const key = `events/${baseInput.hostUserId}/cover.jpg`;
    fileStorage.setSize(key, DEFAULT_MAX_BYTES);

    const event = await useCase.execute({ ...baseInput, coverPhotoStorageKey: key });

    expect(event.coverPhotoStorageKey).toBe(key);
    expect(repo.all()).toHaveLength(1);
  });

  it('cover photo over the byte cap → 422 UNPROCESSABLE, no event persisted', async () => {
    const { repo, publisher, fileStorage, useCase } = buildSut(true);
    const key = `events/${baseInput.hostUserId}/cover.jpg`;
    fileStorage.setSize(key, DEFAULT_MAX_BYTES + 1);

    const err = await useCase
      .execute({ ...baseInput, coverPhotoStorageKey: key })
      .catch((e: unknown) => e);

    expect(err).toBeInstanceOf(AppError);
    const appErr = err as AppError;
    expect(appErr.status).toBe(422);
    expect(appErr.code).toBe('UNPROCESSABLE');
    const details = appErr.details as Record<string, unknown>;
    expect(details.subcode).toBe('COVER_PHOTO_TOO_LARGE');
    expect(details.maxBytes).toBe(DEFAULT_MAX_BYTES);
    expect(details.actualBytes).toBe(DEFAULT_MAX_BYTES + 1);

    expect(repo.all()).toHaveLength(0);
    expect(publisher.published.map((e) => e.type)).not.toContain(EVENT_CREATED);
    expect(publisher.published.map((e) => e.type)).not.toContain(EVENT_PUBLISHED);
  });
});
