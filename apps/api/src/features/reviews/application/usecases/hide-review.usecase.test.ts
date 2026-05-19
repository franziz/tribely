import { describe, expect, it, vi, beforeEach } from 'vitest';
import type { UnitOfWork, TxContext } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import { Review } from '../../domain/entities/review.js';
import { Rating } from '../../domain/value-objects/rating.js';
import type { ReviewRepository } from '../../domain/repositories/review.repository.js';
import { HideReviewUseCase } from './hide-review.usecase.js';

const TX = {} as TxContext;

const makeUnitOfWork = (): UnitOfWork => ({
  run: vi.fn((work: (ctx: TxContext) => Promise<unknown>) =>
    work(TX),
  ) as UnitOfWork['run'],
});

const makeClock = (now = new Date('2025-01-05T12:00:00Z')): Clock => ({
  now: vi.fn(() => now),
});

const makeReview = (hidden = false): Review => {
  const now = new Date('2025-01-01T12:00:00Z');
  const r = Review.submit({
    id: 'rev_001',
    eventId: 'evt_001',
    raterUserId: 'user_rater',
    ratedUserId: 'user_rated',
    rating: Rating.create(4),
    comment: null,
    now,
  });
  if (hidden) {
    r.hide({ hiddenByUserId: 'mod_001', reportId: 'rpt_000', reason: 'Initial', now });
  }
  r.pullEvents();
  return r;
};

describe('HideReviewUseCase', () => {
  let saveSpy: ReturnType<typeof vi.fn>;
  let findByIdSpy: ReturnType<typeof vi.fn>;
  let publishSpy: ReturnType<typeof vi.fn>;
  let reviewRepo: ReviewRepository;
  let unitOfWork: UnitOfWork;
  let publisher: EventPublisher;
  let clock: Clock;
  let useCase: HideReviewUseCase;

  beforeEach(() => {
    saveSpy = vi.fn((): Promise<void> => Promise.resolve());
    findByIdSpy = vi.fn(() => Promise.resolve(makeReview()));
    publishSpy = vi.fn((): Promise<void> => Promise.resolve());
    reviewRepo = {
      save: saveSpy,
      findById: findByIdSpy,
      findByTriple: vi.fn(() => Promise.resolve(null)),
      listByRatedUser: vi.fn(() => Promise.resolve({ rows: [], nextCursor: null })),
      listWrittenBy: vi.fn(() => Promise.resolve({ rows: [], nextCursor: null })),
      aggregateForUser: vi.fn(() =>
        Promise.resolve({
          averageRating: null,
          reviewCount: 0,
          recentVisibleComments: [],
        }),
      ),
    };
    unitOfWork = makeUnitOfWork();
    publisher = { publish: publishSpy };
    clock = makeClock();
    useCase = new HideReviewUseCase(unitOfWork, reviewRepo, publisher, clock);
  });

  it('hides the review and saves it', async () => {
    await useCase.execute({
      moderatorUserId: 'mod_001',
      reviewId: 'rev_001',
      reportId: 'rpt_001',
      reason: 'Harassment',
    });
    expect(saveSpy).toHaveBeenCalled();
    expect(publishSpy).toHaveBeenCalled();
  });

  it('throws 404 when review not found', async () => {
    findByIdSpy.mockResolvedValue(null);
    await expect(
      useCase.execute({
        moderatorUserId: 'mod_001',
        reviewId: 'rev_001',
        reportId: 'rpt_001',
        reason: 'Spam',
      }),
    ).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('is idempotent for already-hidden review — no save or publish', async () => {
    findByIdSpy.mockResolvedValue(makeReview(true));
    await useCase.execute({
      moderatorUserId: 'mod_002',
      reviewId: 'rev_001',
      reportId: 'rpt_002',
      reason: 'Double-report',
    });
    expect(saveSpy).not.toHaveBeenCalled();
    expect(publishSpy).not.toHaveBeenCalled();
  });
});
