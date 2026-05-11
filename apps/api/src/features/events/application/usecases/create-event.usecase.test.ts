import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { EVENT_CREATED } from '../../domain/events/event-created.event.js';
import { EVENT_PUBLISHED } from '../../domain/events/event-published.event.js';
import { CreateEventUseCase, type CreateEventInput } from './create-event.usecase.js';
import {
  FakeEventPublisher,
  FakeEventRepository,
  FakeUnitOfWork,
  FixedClock,
} from './__test__/fakes.js';

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
  costSplit: 'own',
  approvalMode: 'manual',
};

const buildSut = () => {
  const repo = new FakeEventRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new CreateEventUseCase(uow, repo, publisher, clock);
  return { repo, publisher, clock, useCase };
};

describe('CreateEventUseCase', () => {
  it('persists a published event and emits eventCreated + eventPublished', async () => {
    const { repo, publisher, useCase } = buildSut();
    const event = await useCase.execute(baseInput);

    expect(event.status).toBe('published');
    expect(event.hostUserId).toBe('user_1');
    expect(event.venue.city).toBe('Singapore');

    expect(repo.all()).toHaveLength(1);
    expect(publisher.published.map((e) => e.type)).toEqual([EVENT_CREATED, EVENT_PUBLISHED]);
  });

  it('rejects an event whose startsAt is in the past', async () => {
    const { useCase } = buildSut();
    await expect(
      useCase.execute({ ...baseInput, startsAt: new Date(NOW.getTime() - 1000) }),
    ).rejects.toThrowError(AppError);
  });

  it('rejects an invalid category', async () => {
    const { useCase } = buildSut();
    await expect(useCase.execute({ ...baseInput, category: 'nope' })).rejects.toThrowError(
      /category/,
    );
  });

  it('rejects a capacity below the minimum', async () => {
    const { useCase } = buildSut();
    await expect(useCase.execute({ ...baseInput, capacity: 1 })).rejects.toThrowError(/Capacity/);
  });
});
