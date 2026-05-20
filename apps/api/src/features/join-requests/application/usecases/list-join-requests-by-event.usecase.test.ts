import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Event } from '@/features/events/domain/entities/event.js';
import { Capacity } from '@/features/events/domain/value-objects/capacity.js';
import { EventCategory } from '@/features/events/domain/value-objects/event-category.js';
import { VenueCategory } from '@/features/events/domain/value-objects/venue-category.js';
import { Venue } from '@/features/events/domain/value-objects/venue.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { JoinRequest } from '../../domain/entities/join-request.js';
import { ListJoinRequestsByEventUseCase } from './list-join-requests-by-event.usecase.js';
import { FakeEventRepository, FakeJoinRequestRepository, FakeUserRepository } from './fakes.js';

const NOW = new Date('2026-05-11T00:00:00Z');
const STARTS = new Date(NOW.getTime() + 7 * 24 * 60 * 60 * 1000);
const ENDS = new Date(STARTS.getTime() + 3 * 60 * 60 * 1000);
const SNAPSHOT = {
  startsAt: STARTS,
  endsAt: ENDS,
  venue: { address: '18 Raffles Quay', city: 'Singapore', latitude: 1.2806, longitude: 103.8504 },
  hostUserId: 'host_1',
};

const seedEvent = (repo: FakeEventRepository) => {
  const event = Event.create({
    id: 'evt_1',
    hostUserId: 'host_1',
    title: 'Hawker tour',
    description: null,
    venue: Venue.create(SNAPSHOT.venue),
    startsAt: STARTS,
    endsAt: ENDS,
    capacity: Capacity.create(6),
    category: EventCategory.create('food'),
    venueCategory: VenueCategory.create('cafe'),
    costSplit: 'own',
    approvalMode: 'manual',
    now: NOW,
  });
  event.publish(NOW);
  event.pullEvents();
  repo.put(event);
};

const seedUser = (repo: FakeUserRepository, id: string): User => {
  const user = User.rehydrate({
    id,
    email: Email.create(`${id}@test.com`),
    displayName: DisplayName.create(`User-${id}`),
    createdAt: NOW,
    updatedAt: NOW,
    emailVerifiedAt: NOW,
    bio: null,
    avatarUrl: null,
    languages: [],
    interests: [],
    currentCity: null,
    travelerType: null,
    phone: null,
    phoneVerifiedAt: null,
    selfieStatus: null,
    selfieAttemptCount: 0,
    selfieLastFailureCategory: null,
    selfieAppealLockedAt: null,
    deletedAt: null,
  });
  repo.put(user);
  return user;
};

const seedJoinRequest = (
  repo: FakeJoinRequestRepository,
  id: string,
  requesterUserId: string,
  offsetMs = 0,
): JoinRequest => {
  const jr = JoinRequest.request({
    id,
    eventId: 'evt_1',
    requesterUserId,
    now: new Date(NOW.getTime() + offsetMs),
    autoApprove: false,
    hostUserId: 'host_1',
    eventSnapshot: SNAPSHOT,
  });
  jr.pullEvents();
  repo.put(jr);
  return jr;
};

const seedApprovedJoinRequest = (
  repo: FakeJoinRequestRepository,
  id: string,
  requesterUserId: string,
  offsetMs = 0,
): JoinRequest => {
  const jr = JoinRequest.request({
    id,
    eventId: 'evt_1',
    requesterUserId,
    now: new Date(NOW.getTime() + offsetMs),
    autoApprove: false,
    hostUserId: 'host_1',
    eventSnapshot: SNAPSHOT,
  });
  jr.approve({
    by: 'host_1',
    now: new Date(NOW.getTime() + offsetMs + 1000),
    eventSnapshot: SNAPSHOT,
  });
  jr.pullEvents();
  repo.put(jr);
  return jr;
};

const seedRejectedJoinRequest = (
  repo: FakeJoinRequestRepository,
  id: string,
  requesterUserId: string,
  offsetMs = 0,
): JoinRequest => {
  const jr = JoinRequest.request({
    id,
    eventId: 'evt_1',
    requesterUserId,
    now: new Date(NOW.getTime() + offsetMs),
    autoApprove: false,
    hostUserId: 'host_1',
    eventSnapshot: SNAPSHOT,
  });
  jr.reject({
    by: 'host_1',
    reason: 'Not a good fit',
    now: new Date(NOW.getTime() + offsetMs + 1000),
  });
  jr.pullEvents();
  repo.put(jr);
  return jr;
};

const seedCancelledJoinRequest = (
  repo: FakeJoinRequestRepository,
  id: string,
  requesterUserId: string,
  offsetMs = 0,
): JoinRequest => {
  const jr = JoinRequest.request({
    id,
    eventId: 'evt_1',
    requesterUserId,
    now: new Date(NOW.getTime() + offsetMs),
    autoApprove: false,
    hostUserId: 'host_1',
    eventSnapshot: SNAPSHOT,
  });
  jr.cancelByRequester(new Date(NOW.getTime() + offsetMs + 1000));
  jr.pullEvents();
  repo.put(jr);
  return jr;
};

const buildSut = () => {
  const events = new FakeEventRepository();
  const joinRequests = new FakeJoinRequestRepository();
  const users = new FakeUserRepository();
  const useCase = new ListJoinRequestsByEventUseCase(joinRequests, events, users);
  return { events, joinRequests, users, useCase };
};

describe('ListJoinRequestsByEventUseCase', () => {
  it('returns every request on the event for the host, enriched with requester', async () => {
    const { events, joinRequests, users, useCase } = buildSut();
    seedEvent(events);
    seedUser(users, 'user_a');
    seedUser(users, 'user_b');
    seedUser(users, 'user_c');
    seedJoinRequest(joinRequests, 'jr_a', 'user_a', 0);
    seedJoinRequest(joinRequests, 'jr_b', 'user_b', 1000);
    seedJoinRequest(joinRequests, 'jr_c', 'user_c', 2000);

    const result = await useCase.execute({ eventId: 'evt_1', actorUserId: 'host_1' });
    expect(result.joinRequests.map((item) => item.joinRequest.id)).toEqual([
      'jr_a',
      'jr_b',
      'jr_c',
    ]);
    expect(result.joinRequests[0]?.requester.id).toBe('user_a');
  });

  it('scopes a requester to only their own row(s)', async () => {
    const { events, joinRequests, users, useCase } = buildSut();
    seedEvent(events);
    seedUser(users, 'user_a');
    seedUser(users, 'user_b');
    seedJoinRequest(joinRequests, 'jr_a', 'user_a', 0);
    seedJoinRequest(joinRequests, 'jr_b', 'user_b', 1000);

    const result = await useCase.execute({ eventId: 'evt_1', actorUserId: 'user_a' });
    expect(result.joinRequests.map((item) => item.joinRequest.id)).toEqual(['jr_a']);
    expect(result.joinRequests[0]?.requester.id).toBe('user_a');
  });

  it('returns an empty list for a non-host non-requester (NOT 403)', async () => {
    const { events, joinRequests, users, useCase } = buildSut();
    seedEvent(events);
    seedUser(users, 'user_a');
    seedJoinRequest(joinRequests, 'jr_a', 'user_a', 0);

    const result = await useCase.execute({ eventId: 'evt_1', actorUserId: 'stranger' });
    expect(result.joinRequests).toEqual([]);
  });

  it('returns 404 when the event does not exist', async () => {
    const { useCase } = buildSut();
    await expect(
      useCase.execute({ eventId: 'missing', actorUserId: 'host_1' }),
    ).rejects.toThrowError(AppError);
  });

  it('silently drops rows whose requester no longer exists', async () => {
    const { events, joinRequests, useCase } = buildSut();
    // No user seeded in FakeUserRepository — orphaned row
    seedEvent(events);
    seedJoinRequest(joinRequests, 'jr_a', 'ghost_user', 0);

    const result = await useCase.execute({ eventId: 'evt_1', actorUserId: 'host_1' });
    expect(result.joinRequests).toEqual([]);
  });

  it('returns only pending rows for the host when no status filter supplied (default contract)', async () => {
    const { events, joinRequests, users, useCase } = buildSut();
    seedEvent(events);
    seedUser(users, 'user_pending');
    seedUser(users, 'user_approved');
    seedUser(users, 'user_rejected');
    seedUser(users, 'user_cancelled');

    seedJoinRequest(joinRequests, 'jr_pending', 'user_pending', 0);
    seedApprovedJoinRequest(joinRequests, 'jr_approved', 'user_approved', 1000);
    seedRejectedJoinRequest(joinRequests, 'jr_rejected', 'user_rejected', 2000);
    seedCancelledJoinRequest(joinRequests, 'jr_cancelled', 'user_cancelled', 3000);

    const result = await useCase.execute({ eventId: 'evt_1', actorUserId: 'host_1' });

    expect(result.joinRequests).toHaveLength(1);
    expect(result.joinRequests[0]?.joinRequest.id).toBe('jr_pending');
    expect(result.joinRequests[0]?.joinRequest.status).toBe('pending');
  });

  it('returns only approved rows when status=[approved] is supplied (Attending list path)', async () => {
    const { events, joinRequests, users, useCase } = buildSut();
    seedEvent(events);
    seedUser(users, 'user_pending');
    seedUser(users, 'user_approved_a');
    seedUser(users, 'user_approved_b');
    seedUser(users, 'user_rejected');

    seedJoinRequest(joinRequests, 'jr_pending', 'user_pending', 0);
    seedApprovedJoinRequest(joinRequests, 'jr_approved_a', 'user_approved_a', 1000);
    seedApprovedJoinRequest(joinRequests, 'jr_approved_b', 'user_approved_b', 2000);
    seedRejectedJoinRequest(joinRequests, 'jr_rejected', 'user_rejected', 3000);

    const result = await useCase.execute({
      eventId: 'evt_1',
      actorUserId: 'host_1',
      status: ['approved'],
    });

    expect(result.joinRequests).toHaveLength(2);
    const ids = result.joinRequests.map((item) => item.joinRequest.id);
    expect(ids).toContain('jr_approved_a');
    expect(ids).toContain('jr_approved_b');
    for (const item of result.joinRequests) {
      expect(item.joinRequest.status).toBe('approved');
    }
  });

  it('returns empty list for approved status filter when no approved rows exist', async () => {
    const { events, joinRequests, users, useCase } = buildSut();
    seedEvent(events);
    seedUser(users, 'user_pending');
    seedJoinRequest(joinRequests, 'jr_pending', 'user_pending', 0);

    const result = await useCase.execute({
      eventId: 'evt_1',
      actorUserId: 'host_1',
      status: ['approved'],
    });

    expect(result.joinRequests).toHaveLength(0);
  });
});
