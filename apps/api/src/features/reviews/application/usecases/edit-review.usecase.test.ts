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
  run: vi.fn((work: (ctx: TxContext) => Promise<unknown>) => work(TX)) as UnitOfWork['run'],
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
  let saveSpy: ReturnType<typeof vi.fn>;
  let findByIdSpy: ReturnType<typeof vi.fn>;
  let publishSpy: ReturnType<typeof vi.fn>;
  let reviewRepo: ReviewRepository;
  let unitOfWork: UnitOfWork;
  let publisher: EventPublisher;
  let clock: Clock;
  let useCase: EditReviewUseCase;

  beforeEach(() => {
    const review = makeReview({ now: new Date('2025-01-01T12:00:00Z') });
    saveSpy = vi.fn((): Promise<void> => Promise.resolve());
    findByIdSpy = vi.fn(() => Promise.resolve(review));
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
    expect(saveSpy).toHaveBeenCalled();
    expect(publishSpy).toHaveBeenCalled();
  });

  it('throws 404 when review not found', async () => {
    findByIdSpy.mockResolvedValue(null);
    await expect(
      useCase.execute({ raterUserId: 'user_rater', reviewId: 'rev_001', rating: 4 }),
    ).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('throws 403 notAuthor when caller is not the rater', async () => {
    await expect(
      useCase.execute({ raterUserId: 'other_user', reviewId: 'rev_001', rating: 4 }),
    ).rejects.toMatchObject({
      code: 'FORBIDDEN',
      details: { subcode: 'reviews.notAuthor' },
    });
  });

  it('throws 404 when review is hidden', async () => {
    findByIdSpy.mockResolvedValue(makeReview({ hidden: true }));
    await expect(
      useCase.execute({ raterUserId: 'user_rater', reviewId: 'rev_001', rating: 4 }),
    ).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('throws 409 editWindowExpired when outside 24h window', async () => {
    const createdAt = new Date('2025-01-01T12:00:00Z');
    const afterWindow = new Date(createdAt.getTime() + 24 * 60 * 60 * 1000 + 1);
    clock = makeClock(afterWindow);
    useCase = new EditReviewUseCase(unitOfWork, reviewRepo, publisher, clock);

    await expect(
      useCase.execute({ raterUserId: 'user_rater', reviewId: 'rev_001', rating: 4 }),
    ).rejects.toMatchObject({
      code: 'CONFLICT',
      details: { subcode: 'reviews.editWindowExpired' },
    });
  });
});
