import { describe, expect, it, vi, beforeEach } from 'vitest';
import type { UnitOfWork, TxContext } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import { Review } from '../../domain/entities/review.js';
import { Rating } from '../../domain/value-objects/rating.js';
import { ReviewComment } from '../../domain/value-objects/review-comment.js';
import type { ReviewRepository } from '../../domain/repositories/review.repository.js';
import { EditReviewUseCase } from './edit-review.usecase.js';

const TX = {} as TxContext;

const makeUnitOfWork = (): UnitOfWork => ({
  run: vi.fn(async (work) => work(TX)),
});

const makePublisher = (): EventPublisher => ({
  publish: vi.fn(async () => {}),
});

const makeClock = (now = new Date('2025-01-01T13:00:00Z')): Clock => ({
  now: vi.fn(() => now),
});

const makeReview = (options?: { hidden?: boolean; now?: Date }): Review => {
  const now = options?.now ?? new Date('2025-01-01T12:00:00Z');
  const r = Review.submit({
    id: 'rev_001',
    eventId: 'evt_001',
    raterUserId: 'user_rater',
    ratedUserId: 'user_rated',
    rating: Rating.create(3),
    comment: ReviewComment.create('OK'),
    now,
  });
  if (options?.hidden) {
    r.hide({ hiddenByUserId: 'mod_001', reportId: 'rpt_001', reason: 'Spam', now });
  }
  r.pullEvents();
  return r;
};

describe('EditReviewUseCase', () => {
  let reviewRepo: ReviewRepository;
  let unitOfWork: UnitOfWork;
  let publisher: EventPublisher;
  let clock: Clock;
  let useCase: EditReviewUseCase;

  beforeEach(() => {
    const review = makeReview({ now: new Date('2025-01-01T12:00:00Z') });
    reviewRepo = {
      save: vi.fn(async () => {}),
      findById: vi.fn(async () => review),
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
    clock = makeClock(new Date('2025-01-01T13:00:00Z')); // +1h — within window
    useCase = new EditReviewUseCase(unitOfWork, reviewRepo, publisher, clock);
  });

  it('happy path: updates rating and comment within window', async () => {
    await expect(
      useCase.execute({
        raterUserId: 'user_rater',
        reviewId: 'rev_001',
        rating: 5,
        comment: 'Better!',
      }),
    ).resolves.toBeUndefined();
    expect(reviewRepo.save).toHaveBeenCalled();
    expect(publisher.publish).toHaveBeenCalled();
  });

  it('throws 404 when review not found', async () => {
    vi.mocked(reviewRepo.findById).mockResolvedValue(null);
    await expect(
      useCase.execute({ raterUserId: 'user_rater', reviewId: 'rev_001', rating: 4 }),
    ).rejects.toThrow(expect.objectContaining({ code: 'NOT_FOUND' }));
  });

  it('throws 403 notAuthor when caller is not the rater', async () => {
    await expect(
      useCase.execute({ raterUserId: 'other_user', reviewId: 'rev_001', rating: 4 }),
    ).rejects.toThrow(
      expect.objectContaining({
        code: 'FORBIDDEN',
        details: expect.objectContaining({ subcode: 'reviews.notAuthor' }),
      }),
    );
  });

  it('throws 404 when review is hidden', async () => {
    vi.mocked(reviewRepo.findById).mockResolvedValue(makeReview({ hidden: true }));
    await expect(
      useCase.execute({ raterUserId: 'user_rater', reviewId: 'rev_001', rating: 4 }),
    ).rejects.toThrow(expect.objectContaining({ code: 'NOT_FOUND' }));
  });

  it('throws 409 editWindowExpired when outside 24h window', async () => {
    const createdAt = new Date('2025-01-01T12:00:00Z');
    const afterWindow = new Date(createdAt.getTime() + 24 * 60 * 60 * 1000 + 1);
    clock = makeClock(afterWindow);
    useCase = new EditReviewUseCase(unitOfWork, reviewRepo, publisher, clock);

    await expect(
      useCase.execute({ raterUserId: 'user_rater', reviewId: 'rev_001', rating: 4 }),
    ).rejects.toThrow(
      expect.objectContaining({
        code: 'CONFLICT',
        details: expect.objectContaining({ subcode: 'reviews.editWindowExpired' }),
      }),
    );
  });
});
