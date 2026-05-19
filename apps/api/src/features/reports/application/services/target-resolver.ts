import type { ReviewRepository } from '@/features/reviews/domain/repositories/review.repository.js';
import type { Review } from '@/features/reviews/domain/entities/review.js';
import type { ReportTargetType } from '../../domain/value-objects/report-target.js';

/**
 * Result returned by `TargetResolver.resolve(...)` for the 'review' target type.
 */
export type ReviewTargetResult = { kind: 'review'; review: Review } | { kind: 'not-found' };

/**
 * Result returned by `TargetResolver.resolve(...)` for unimplemented target types.
 */
export type NotImplementedResult = { kind: 'not-implemented' };

export type TargetResolverResult = ReviewTargetResult | NotImplementedResult;

/**
 * Strategy-map-based resolver that looks up the concrete entity referenced
 * by a polymorphic (targetType, targetId) pair.
 *
 * For `'review'`: delegates to `ReviewRepository.findById`.
 * For `'user'` and `'event'`: returns `{ kind: 'not-implemented' }` — the
 * HTTP schema already rejects these at the Zod layer, but the resolver
 * provides a clear escape hatch for any code that reaches this layer.
 *
 * Adding a new target type: add a branch to the switch and inject the new
 * repository as a constructor argument.
 */
export class TargetResolver {
  constructor(private readonly reviews: ReviewRepository) {}

  async resolve(targetType: ReportTargetType, targetId: string): Promise<TargetResolverResult> {
    switch (targetType) {
      case 'review': {
        const review = await this.reviews.findById(targetId);
        if (!review) return { kind: 'not-found' };
        return { kind: 'review', review };
      }
      case 'user':
      case 'event':
        return { kind: 'not-implemented' };
    }
  }
}
