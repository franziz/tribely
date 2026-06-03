import { describe, expect, it, vi, beforeEach } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork, TxContext } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
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
import { SubmitReviewUseCase } from './submit-review.usecase.js';

const TX = {} as TxContext;

const makeUnitOfWork = (): UnitOfWork => ({
  run: vi.fn((work: (ctx: TxContext) => Promise<unknown>) => work(TX)) as UnitOfWork['run'],
});

const makeClock = (now = new Date('2025-06-01T12:00:00Z')): Clock => ({
  now: vi.fn(() => now),
});

const makeCompletedEvent = (): Event => {
  const e = Event.rehydrate({
    id: 'evt_001',
    hostUserId: 'user_host',
    title: 'Dinner',
    description: null,
    venue: Venue.create({
      address: '1 Test St',
      city: 'Singapore',
      latitude: 1.3,
      longitude: 103.8,
    }),
    startsAt: new Date('2025-05-01T18:00:00Z'),
    endsAt: new Date('2025-05-01T20:00:00Z'),
    capacity: Capacity.create(5),
    category: EventCategory.create('food'),
    venueCategory: VenueCategory.create('cafe'),
    costNotes: null,
    approvalMode: 'manual',
    status: 'completed',
    cancellationReason: null,
    createdAt: new Date('2025-04-01T00:00:00Z'),
    updatedAt: new Date('2025-05-01T20:00:00Z'),
  });
  e.pullEvents();
  return e;
};

const makeApprovedJoinRequest = (): JoinRequest => {
  const jr = JoinRequest.rehydrate({
    id: 'jr_001',
    eventId: 'evt_001',
    requesterUserId: 'user_guest',
    requestedAt: new Date('2025-04-15T00:00:00Z'),
    status: 'approved',
    decidedAt: new Date('2025-04-16T00:00:00Z'),
    decidedByUserId: 'user_host',
    decisionReason: null,
  });
  jr.pullEvents();
  return jr;
};

describe('SubmitReviewUseCase', () => {
  let saveSpy: ReturnType<typeof vi.fn>;
  let findByTripleSpy: ReturnType<typeof vi.fn>;
  let publishSpy: ReturnType<typeof vi.fn>;
  let eventFindByIdSpy: ReturnType<typeof vi.fn>;
  let joinRequestFindByEventSpy: ReturnType<typeof vi.fn>;
  let reviewRepo: ReviewRepository;
  let eventRepo: EventRepository;
  let joinRequestRepo: JoinRequestRepository;
  let unitOfWork: UnitOfWork;
  let publisher: EventPublisher;
  let clock: Clock;
  let useCase: SubmitReviewUseCase;

  beforeEach(() => {
    saveSpy = vi.fn((): Promise<void> => Promise.resolve());
    findByTripleSpy = vi.fn(() => Promise.resolve(null));
    publishSpy = vi.fn((): Promise<void> => Promise.resolve());
    eventFindByIdSpy = vi.fn(() => Promise.resolve(makeCompletedEvent()));
    joinRequestFindByEventSpy = vi.fn(() => Promise.resolve([makeApprovedJoinRequest()]));

    reviewRepo = {
      save: saveSpy,
      findById: vi.fn(() => Promise.resolve(null)),
      findByTriple: findByTripleSpy,
      findExistingTriples: vi.fn(() => Promise.resolve(new Set<string>())),
      listByRatedUser: vi.fn(() => Promise.resolve({ rows: [], nextCursor: null })),
      listWrittenBy: vi.fn(() => Promise.resolve({ rows: [], nextCursor: null })),
      aggregateForUser: vi.fn(() =>
        Promise.resolve({
          averageRating: null,
          reviewCount: 0,
          recentVisibleComments: [],
        }),
      ),
      deleteAllForUser: vi.fn(
        (_userId: string, _ctx: unknown): Promise<number> => Promise.resolve(0),
      ),
    };
    eventRepo = {
      findById: eventFindByIdSpy,
      findByIdForUpdate: vi.fn(() => Promise.resolve(null)),
      save: vi.fn((): Promise<void> => Promise.resolve()),
      findManyForListing: vi.fn(() => Promise.resolve({ events: [], nextCursor: null })),
      countCompletedByHost: vi.fn(() => Promise.resolve(0)),
      findCompletedForUserBetween: vi.fn(() => Promise.resolve([])),
      pseudonymiseHostForUser: vi.fn(() => Promise.resolve(0)),
    };
    joinRequestRepo = {
      findById: vi.fn(() => Promise.resolve(null)),
      findActiveByEventAndRequester: vi.fn(() => Promise.resolve(null)),
      findLatestByRequesterAndEvent: vi.fn(() => Promise.resolve(null)),
      save: vi.fn((): Promise<void> => Promise.resolve()),
      countApproved: vi.fn(() => Promise.resolve(0)),
      findByEvent: joinRequestFindByEventSpy,
      listByRequester: vi.fn(() => Promise.resolve({ joinRequests: [], nextCursor: null })),
      listApprovedByEvents: vi.fn(() => Promise.resolve([])),
      pseudonymiseAuthorForUser: vi.fn(() => Promise.resolve(0)),
    };
    unitOfWork = makeUnitOfWork();
    publisher = { publish: publishSpy };
    clock = makeClock();
    useCase = new SubmitReviewUseCase(
      unitOfWork,
      reviewRepo,
      eventRepo,
      joinRequestRepo,
      publisher,
      clock,
    );
  });

  it('happy path: host rates guest', async () => {
    const review = await useCase.execute({
      raterUserId: 'user_host',
      eventId: 'evt_001',
      ratedUserId: 'user_guest',
      rating: 4,
      comment: 'Great guest!',
    });

    expect(review.rating.value).toBe(4);
    expect(review.comment?.value).toBe('Great guest!');
    expect(saveSpy).toHaveBeenCalledWith(review, TX);
    expect(publishSpy).toHaveBeenCalled();
  });

  it('happy path: guest rates host', async () => {
    joinRequestFindByEventSpy.mockResolvedValue([makeApprovedJoinRequest()]);
    const review = await useCase.execute({
      raterUserId: 'user_guest',
      eventId: 'evt_001',
      ratedUserId: 'user_host',
      rating: 5,
    });
    expect(review.rating.value).toBe(5);
  });

  it('throws 404 when event not found', async () => {
    eventFindByIdSpy.mockResolvedValue(null);
    await expect(
      useCase.execute({ raterUserId: 'u1', eventId: 'evt_001', ratedUserId: 'u2', rating: 3 }),
    ).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('throws 403 eventNotCompleted when event not completed', async () => {
    const draftEvent = Event.rehydrate({
      id: 'evt_001',
      hostUserId: 'user_host',
      title: 'Draft',
      description: null,
      venue: Venue.create({
        address: '1 Test St',
        city: 'Singapore',
        latitude: 1.3,
        longitude: 103.8,
      }),
      startsAt: new Date('2025-05-01T18:00:00Z'),
      endsAt: new Date('2025-05-01T20:00:00Z'),
      capacity: Capacity.create(5),
      category: EventCategory.create('food'),
      venueCategory: VenueCategory.create('cafe'),
      costNotes: null,
      approvalMode: 'manual',
      status: 'published',
      cancellationReason: null,
      createdAt: new Date('2025-04-01T00:00:00Z'),
      updatedAt: new Date('2025-04-01T00:00:00Z'),
    });
    draftEvent.pullEvents();
    eventFindByIdSpy.mockResolvedValue(draftEvent);

    await expect(
      useCase.execute({
        raterUserId: 'user_host',
        eventId: 'evt_001',
        ratedUserId: 'user_guest',
        rating: 3,
      }),
    ).rejects.toMatchObject({
      code: 'FORBIDDEN',
      details: { subcode: 'reviews.eventNotCompleted' },
    });
  });

  it('throws 403 selfReview when rater === rated', async () => {
    await expect(
      useCase.execute({
        raterUserId: 'user_host',
        eventId: 'evt_001',
        ratedUserId: 'user_host',
        rating: 5,
      }),
    ).rejects.toMatchObject({
      details: { subcode: 'reviews.selfReview' },
    });
  });

  it('throws 403 notParticipant when neither user is the host', async () => {
    await expect(
      useCase.execute({
        raterUserId: 'outsider',
        eventId: 'evt_001',
        ratedUserId: 'user_guest',
        rating: 3,
      }),
    ).rejects.toMatchObject({
      details: { subcode: 'reviews.notParticipant' },
    });
  });

  it('throws 403 noApprovedPair when no approved join request', async () => {
    joinRequestFindByEventSpy.mockResolvedValue([]);
    await expect(
      useCase.execute({
        raterUserId: 'user_host',
        eventId: 'evt_001',
        ratedUserId: 'user_guest',
        rating: 3,
      }),
    ).rejects.toMatchObject({
      details: { subcode: 'reviews.noApprovedPair' },
    });
  });

  it('throws 409 alreadyReviewed when duplicate triple exists', async () => {
    // Create a fake existing review
    const { Review } = await import('../../domain/entities/review.js');
    const { Rating } = await import('../../domain/value-objects/rating.js');
    const existingReview = Review.submit({
      id: 'rev_existing',
      eventId: 'evt_001',
      raterUserId: 'user_host',
      ratedUserId: 'user_guest',
      rating: Rating.create(3),
      comment: null,
      now: new Date(),
    });
    existingReview.pullEvents();
    findByTripleSpy.mockResolvedValue(existingReview);

    await expect(
      useCase.execute({
        raterUserId: 'user_host',
        eventId: 'evt_001',
        ratedUserId: 'user_guest',
        rating: 4,
      }),
    ).rejects.toMatchObject({
      code: 'CONFLICT',
      details: { subcode: 'reviews.alreadyReviewed' },
    });
  });

  it('throws 400 for invalid rating', async () => {
    await expect(
      useCase.execute({
        raterUserId: 'user_host',
        eventId: 'evt_001',
        ratedUserId: 'user_guest',
        rating: 6,
      }),
    ).rejects.toThrow(AppError);
  });
});
