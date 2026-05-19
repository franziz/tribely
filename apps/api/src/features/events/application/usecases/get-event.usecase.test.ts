import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import type { VerificationSignalId } from '@/features/users/application/projections/is-verified.projection.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { Event } from '../../domain/entities/event.js';
import { Capacity } from '../../domain/value-objects/capacity.js';
import { EventCategory } from '../../domain/value-objects/event-category.js';
import { VenueCategory } from '../../domain/value-objects/venue-category.js';
import { Venue } from '../../domain/value-objects/venue.js';
import { GetEventUseCase } from './get-event.usecase.js';
import { FakeEventRepository, FakeUserRepository } from './fakes.js';

const NOW = new Date('2026-05-11T00:00:00Z');

const DEFAULT_SIGNAL_SET: VerificationSignalId[] = ['email', 'phone', 'selfie'];

const buildSut = (signalSet: VerificationSignalId[] = DEFAULT_SIGNAL_SET) => {
  const events = new FakeEventRepository();
  const users = new FakeUserRepository();
  const useCase = new GetEventUseCase(events, users, signalSet);
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
    expect(result.host).toEqual({ id: 'user_1', displayName: 'Hostie', isVerified: false });
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

  it('default signal set + host with emailVerifiedAt null → isVerified false', async () => {
    const { events, users, useCase } = buildSut(DEFAULT_SIGNAL_SET);
    const host = User.register({
      id: 'user_unverified',
      email: Email.create('unverified@example.com'),
      displayName: DisplayName.create('Unverified'),
      now: NOW,
    });
    host.pullEvents();
    users.put(host);
    events.put(buildEvent('evt_unverified', 'user_unverified'));

    const result = await useCase.execute({ id: 'evt_unverified' });

    expect(result.host.isVerified).toBe(false);
  });

  it('default signal set + host with emailVerifiedAt set → isVerified false (AC5: phone+selfie signals hardcoded null)', async () => {
    const { events, users, useCase } = buildSut(DEFAULT_SIGNAL_SET);
    const host = User.register({
      id: 'user_email_verified',
      email: Email.create('emailverified@example.com'),
      displayName: DisplayName.create('EmailVerified'),
      now: NOW,
    });
    host.verifyEmail(NOW);
    host.pullEvents();
    users.put(host);
    events.put(buildEvent('evt_email_verified', 'user_email_verified'));

    const result = await useCase.execute({ id: 'evt_email_verified' });

    // Even with emailVerifiedAt set, phone and selfie signals are hardcoded null
    // in the use case until TRI-16 / TRI-23 ship — so isVerified stays false.
    expect(result.host.isVerified).toBe(false);
  });

  it('custom signal set [email] + host with emailVerifiedAt set → isVerified true (asserts constructor wiring)', async () => {
    const { events, users, useCase } = buildSut(['email']);
    const host = User.register({
      id: 'user_email_only',
      email: Email.create('emailonly@example.com'),
      displayName: DisplayName.create('EmailOnly'),
      now: NOW,
    });
    host.verifyEmail(NOW);
    host.pullEvents();
    users.put(host);
    events.put(buildEvent('evt_email_only', 'user_email_only'));

    const result = await useCase.execute({ id: 'evt_email_only' });

    expect(result.host.isVerified).toBe(true);
  });
});
