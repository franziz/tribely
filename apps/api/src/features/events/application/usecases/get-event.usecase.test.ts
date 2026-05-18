import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { Event } from '../../domain/entities/event.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
import { VenueCategory } from '../../domain/value-objects/venue-category.js';
import { Venue } from '../../domain/value-objects/venue.js';
import { GetEventUseCase } from './get-event.usecase.js';
import { FakeEventRepository, FakeUserRepository } from './__test__/fakes.js';

const NOW = new Date('2026-05-11T00:00:00Z');

const buildSut = () => {
  const events = new FakeEventRepository();
  const users = new FakeUserRepository();
  const useCase = new GetEventUseCase(events, users);
  return { events, users, useCase };
};

const buildEvent = (id: string, hostUserId: string): Event => {
  const event = Event.create({
    id,
    hostUserId,
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
  return event;
};

describe('GetEventUseCase', () => {
  it('returns the event + a minimal public host projection', async () => {
    const { events, users, useCase } = buildSut();
    const host = User.register({
      id: 'user_1',
      email: Email.create('host@example.com'),
      displayName: DisplayName.create('Hostie'),
      now: NOW,
    });
    host.pullEvents();
    users.put(host);
    events.put(buildEvent('evt_1', 'user_1'));

    const result = await useCase.execute({ id: 'evt_1' });

    expect(result.event.id).toBe('evt_1');
    expect(result.host).toEqual({ id: 'user_1', displayName: 'Hostie' });
  });

  it('throws notFound when the event does not exist', async () => {
    const { useCase } = buildSut();
    await expect(useCase.execute({ id: 'nope' })).rejects.toThrowError(AppError);
  });

  it('throws internal when the host has vanished', async () => {
    const { events, useCase } = buildSut();
    events.put(buildEvent('evt_orphan', 'missing'));
    await expect(useCase.execute({ id: 'evt_orphan' })).rejects.toThrowError(/missing host/);
  });
});
