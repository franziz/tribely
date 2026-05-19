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
  run: vi.fn(async (work) => work(TX)),
});

const makePublisher = (): EventPublisher => ({
  publish: vi.fn(async () => {}),
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
  let reviewRepo: ReviewRepository;
  let unitOfWork: UnitOfWork;
  let publisher: EventPublisher;
  let clock: Clock;
  let useCase: HideReviewUseCase;

  beforeEach(() => {
    reviewRepo = {
      save: vi.fn(async () => {}),
      findById: vi.fn(async () => makeReview()),
      findByTriple: vi.fn(async () => null),
      listByRatedUser: vi.fn(async () => ({ rows: [], nextCursor: null })),
      listWrittenBy: vi.fn(async () => ({ rows: [], nextCursor: null })),
      aggregateForUser: vi.fn(async () => ({
        averageRating: null,
        reviewCount: 0,
        recentVisibleComments: [],
      })),
    };
    unitOfWork = makeUnitOfWork();
    publisher = makePublisher();
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
    expect(reviewRepo.save).toHaveBeenCalled();
    expect(publisher.publish).toHaveBeenCalled();
  });

  it('throws 404 when review not found', async () => {
    vi.mocked(reviewRepo.findById).mockResolvedValue(null);
    await expect(
      useCase.execute({
        moderatorUserId: 'mod_001',
        reviewId: 'rev_001',
        reportId: 'rpt_001',
        reason: 'Spam',
      }),
    ).rejects.toThrow(expect.objectContaining({ code: 'NOT_FOUND' }));
  });

  it('is idempotent for already-hidden review — no save or publish', async () => {
    vi.mocked(reviewRepo.findById).mockResolvedValue(makeReview(true));
    await useCase.execute({
      moderatorUserId: 'mod_002',
      reviewId: 'rev_001',
      reportId: 'rpt_002',
      reason: 'Double-report',
    });
    expect(reviewRepo.save).not.toHaveBeenCalled();
    expect(publisher.publish).not.toHaveBeenCalled();
  });
});
