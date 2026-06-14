import { describe, expect, it, vi, beforeEach } from 'vitest';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import { Event } from '@/features/events/domain/entities/event.js';
import { Capacity } from '@/features/events/domain/value-objects/capacity.js';
import { EventCategory } from '@/features/events/domain/value-objects/event-category.js';
import { VenueCategory } from '@/features/events/domain/value-objects/venue-category.js';
import { Venue } from '@/features/events/domain/value-objects/venue.js';
import { JoinRequest } from '@/features/join-requests/domain/entities/join-request.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { JoinRequestRepository } from '@/features/join-requests/domain/repositories/join-request.repository.js';
import type { ReviewRepository } from '../../domain/repositories/review.repository.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { GetReviewEligibilityUseCase } from './get-review-eligibility.usecase.js';
import { User } from '@/features/users/domain/entities/user.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';

// A clock whose now() sits exactly 48h after endsAt — well inside the 24h–7d window.
const NOW = new Date('2025-06-03T20:00:00Z');
// endsAt is 48h before NOW → inside window.
const ENDS_AT_IN_WINDOW = new Date('2025-06-01T20:00:00Z');
// endsAt is 2h before NOW → < 24h ago (too recent).
const ENDS_AT_TOO_RECENT = new Date('2025-06-03T18:00:00Z');
// endsAt is 8 days before NOW → > 7d ago (window closed).
const ENDS_AT_TOO_OLD = new Date('2025-05-26T20:00:00Z');

const makeEvent = (overrides?: Partial<Parameters<typeof Event.rehydrate>[0]>): Event => {
  const e = Event.rehydrate({
    id: 'evt_001',
    hostUserId: 'user_host',
    title: 'Drinks',
    description: null,
    venue: Venue.create({
      address: '1 Test St',
      city: 'Singapore',
      latitude: 1.3,
      longitude: 103.8,
    }),
    startsAt: new Date('2025-06-01T18:00:00Z'),
    endsAt: ENDS_AT_IN_WINDOW,
    capacity: Capacity.create(5),
    category: EventCategory.create('social'),
    venueCategory: VenueCategory.create('bar'),
    costNotes: null,
    approvalMode: 'manual',
    status: 'completed',
    cancellationReason: null,
    createdAt: new Date('2025-05-01T00:00:00Z'),
    updatedAt: new Date('2025-06-01T20:00:00Z'),
    ...overrides,
  });
  e.pullEvents();
  return e;
};

const makeApprovedJoinRequest = (): JoinRequest => {
  const jr = JoinRequest.rehydrate({
    id: 'jr_001',
    eventId: 'evt_001',
    requesterUserId: 'user_guest',
    requestedAt: new Date('2025-05-15T00:00:00Z'),
    status: 'approved',
    decidedAt: new Date('2025-05-16T00:00:00Z'),
    decidedByUserId: 'user_host',
    decisionReason: null,
  });
  jr.pullEvents();
  return jr;
};

const makeHost = (): User => {
  const u = User.register({
    id: 'user_host',
    email: Email.create('host@example.com'),
    displayName: DisplayName.create('Alice'),
    now: new Date('2025-01-01T00:00:00Z'),
  });
  u.pullEvents();
  return u;
};

describe('GetReviewEligibilityUseCase', () => {
  let eventRepo: EventRepository;
  let joinRequestRepo: JoinRequestRepository;
  let reviewRepo: ReviewRepository;
  let userRepo: UserRepository;
  let clock: Clock;
  let useCase: GetReviewEligibilityUseCase;

  beforeEach(() => {
    eventRepo = {
      findById: vi.fn(() => Promise.resolve(makeEvent())),
      findByIdForUpdate: vi.fn(() => Promise.resolve(null)),
      save: vi.fn(() => Promise.resolve()),
      findManyForListing: vi.fn(() => Promise.resolve({ events: [], nextCursor: null })),
      countCompletedByHost: vi.fn(() => Promise.resolve(0)),
      findCompletedForUserBetween: vi.fn(() => Promise.resolve([])),
      pseudonymiseHostForUser: vi.fn(() => Promise.resolve(0)),
    };
    joinRequestRepo = {
      findById: vi.fn(() => Promise.resolve(null)),
      findActiveByEventAndRequester: vi.fn(() => Promise.resolve(null)),
      findLatestByRequesterAndEvent: vi.fn(() => Promise.resolve(null)),
      save: vi.fn(() => Promise.resolve()),
      countApproved: vi.fn(() => Promise.resolve(0)),
      findByEvent: vi.fn(() => Promise.resolve([makeApprovedJoinRequest()])),
      listByRequester: vi.fn(() => Promise.resolve({ joinRequests: [], nextCursor: null })),
      listApprovedByEvents: vi.fn(() => Promise.resolve([])),
      pseudonymiseAuthorForUser: vi.fn(() => Promise.resolve(0)),
    };
    reviewRepo = {
      save: vi.fn(() => Promise.resolve()),
      findById: vi.fn(() => Promise.resolve(null)),
      findByTriple: vi.fn(() => Promise.resolve(null)),
      findExistingTriples: vi.fn(() => Promise.resolve(new Set<string>())),
      listByRatedUser: vi.fn(() => Promise.resolve({ rows: [], nextCursor: null })),
      listWrittenBy: vi.fn(() => Promise.resolve({ rows: [], nextCursor: null })),
      aggregateForUser: vi.fn(() =>
        Promise.resolve({ averageRating: null, reviewCount: 0, recentVisibleComments: [] }),
      ),
      deleteAllForUser: vi.fn((_userId: string, _ctx: unknown): Promise<number> =>
        Promise.resolve(0),
      ),
    };
    userRepo = {
      findById: vi.fn(() => Promise.resolve(makeHost())),
      findByIds: vi.fn(() => Promise.resolve([])),
      findByEmail: vi.fn(() => Promise.resolve(null)),
      findByVerifiedPhone: vi.fn(() => Promise.resolve(null)),
      save: vi.fn(() => Promise.resolve()),
    };
    clock = { now: vi.fn(() => NOW) };
    useCase = new GetReviewEligibilityUseCase(
      eventRepo,
      joinRequestRepo,
      reviewRepo,
      userRepo,
      clock,
    );
  });

  it('eligible: viewer is approved joiner, event in 24h–7d window', async () => {
    const result = await useCase.execute({ viewerId: 'user_guest', eventId: 'evt_001' });

    expect(result.eligible).toBe(true);
    expect(result.ratedUserId).toBe('user_host');
    expect(result.hostDisplayName).toBe('Alice');
  });

  it('ineligible: event not found', async () => {
    vi.mocked(eventRepo.findById).mockResolvedValue(null);
    const result = await useCase.execute({ viewerId: 'user_guest', eventId: 'evt_001' });
    expect(result).toEqual({ eligible: false, ratedUserId: null, hostDisplayName: null });
  });

  it('ineligible: event not completed', async () => {
    vi.mocked(eventRepo.findById).mockResolvedValue(makeEvent({ status: 'published' }));
    const result = await useCase.execute({ viewerId: 'user_guest', eventId: 'evt_001' });
    expect(result).toEqual({ eligible: false, ratedUserId: null, hostDisplayName: null });
  });

  it('ineligible: viewer is the host', async () => {
    const result = await useCase.execute({ viewerId: 'user_host', eventId: 'evt_001' });
    expect(result).toEqual({ eligible: false, ratedUserId: null, hostDisplayName: null });
  });

  it('ineligible: viewer has no approved join request', async () => {
    vi.mocked(joinRequestRepo.findByEvent).mockResolvedValue([]);
    const result = await useCase.execute({ viewerId: 'user_guest', eventId: 'evt_001' });
    expect(result).toEqual({ eligible: false, ratedUserId: null, hostDisplayName: null });
  });

  it('ineligible: viewer already reviewed the host for this event', async () => {
    vi.mocked(reviewRepo.findExistingTriples).mockResolvedValue(
      new Set(['evt_001:user_host']),
    );
    const result = await useCase.execute({ viewerId: 'user_guest', eventId: 'evt_001' });
    expect(result).toEqual({ eligible: false, ratedUserId: null, hostDisplayName: null });
  });

  it('ineligible: event ended less than 24h ago (too recent)', async () => {
    vi.mocked(eventRepo.findById).mockResolvedValue(makeEvent({ endsAt: ENDS_AT_TOO_RECENT }));
    const result = await useCase.execute({ viewerId: 'user_guest', eventId: 'evt_001' });
    expect(result).toEqual({ eligible: false, ratedUserId: null, hostDisplayName: null });
  });

  it('ineligible: event ended more than 7 days ago (window closed)', async () => {
    vi.mocked(eventRepo.findById).mockResolvedValue(makeEvent({ endsAt: ENDS_AT_TOO_OLD }));
    const result = await useCase.execute({ viewerId: 'user_guest', eventId: 'evt_001' });
    expect(result).toEqual({ eligible: false, ratedUserId: null, hostDisplayName: null });
  });

  it('findByEvent is called with the viewer as requesterUserId and status approved', async () => {
    await useCase.execute({ viewerId: 'user_guest', eventId: 'evt_001' });
    expect(joinRequestRepo.findByEvent).toHaveBeenCalledWith('evt_001', {
      requesterUserId: 'user_guest',
      status: ['approved'],
    });
  });

  it('findExistingTriples is called with correct pair', async () => {
    await useCase.execute({ viewerId: 'user_guest', eventId: 'evt_001' });
    expect(reviewRepo.findExistingTriples).toHaveBeenCalledWith({
      raterUserId: 'user_guest',
      pairs: [{ eventId: 'evt_001', ratedUserId: 'user_host' }],
    });
  });
});
