import { describe, expect, it, vi } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import type { ReviewRepository } from '@/features/reviews/domain/repositories/review.repository.js';
import { TargetResolver } from './target-resolver.js';

const makeReviewRepoStub = (review: unknown = null): ReviewRepository => ({
  findById: vi.fn().mockResolvedValue(review),
  findByTriple: vi.fn(),
  findExistingTriples: vi.fn().mockResolvedValue(new Set()),
  save: vi.fn(),
  listByRatedUser: vi.fn(),
  listWrittenBy: vi.fn(),
  aggregateForUser: vi.fn(),
});

describe('TargetResolver', () => {
  describe('review target type', () => {
    it('returns kind=review when review is found', async () => {
      const fakeReview = { id: createId() };
      const repo = makeReviewRepoStub(fakeReview);
      const resolver = new TargetResolver(repo);
      const result = await resolver.resolve('review', fakeReview.id);
      expect(result.kind).toBe('review');
      if (result.kind === 'review') {
        expect(result.review).toBe(fakeReview);
      }
    });

    it('returns kind=not-found when review does not exist', async () => {
      const repo = makeReviewRepoStub(null);
      const resolver = new TargetResolver(repo);
      const result = await resolver.resolve('review', createId());
      expect(result.kind).toBe('not-found');
    });
  });

  describe('not-implemented target types', () => {
    it('returns kind=not-implemented for user target type', async () => {
      const repo = makeReviewRepoStub();
      const resolver = new TargetResolver(repo);
      const result = await resolver.resolve('user', createId());
      expect(result.kind).toBe('not-implemented');
    });

    it('returns kind=not-implemented for event target type', async () => {
      const repo = makeReviewRepoStub();
      const resolver = new TargetResolver(repo);
      const result = await resolver.resolve('event', createId());
      expect(result.kind).toBe('not-implemented');
    });
  });
});
