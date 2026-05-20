import { AppError } from '@/core/errors/app-error.js';
import type { ReviewRepository } from '@/features/reviews/domain/repositories/review.repository.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import {
  computeIsVerified,
  type VerificationSignalId,
} from '../projections/is-verified.projection.js';
import type { GetUserResult } from '../dto/get-user-result.dto.js';

export interface GetUserInput {
  /** ID of the profile to fetch. */
  id: string;
  /**
   * ID of the authenticated caller viewing the profile.
   * When provided, the review aggregate is computed from this viewer's
   * perspective (block filter + mutual-window applied).
   * When absent (e.g. unauthenticated public access), the profile owner is
   * used as the viewer — block filter is skipped and mutual-window applied
   * from the subject's own perspective.
   */
  viewerId?: string;
}

export class GetUserUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly signalSet: VerificationSignalId[],
    private readonly reviews: ReviewRepository,
  ) {}

  async execute(input: GetUserInput): Promise<GetUserResult> {
    const user = await this.users.findById(input.id);
    if (!user) throw AppError.notFound(`User ${input.id} not found`);

    const isVerified = computeIsVerified(
      {
        emailVerifiedAt: user.emailVerifiedAt,
        // TODO(TRI-16): replace with user.phoneVerifiedAt once phone column lands
        phoneVerifiedAt: null,
        // TODO(TRI-23): replace with user.selfieApprovedAt once selfie column lands
        selfieApprovedAt: null,
      },
      this.signalSet,
    );

    // Use the explicit viewerId when supplied; fall back to the subject's own
    // ID so unauthenticated callers still get a stable, self-consistent view.
    // The repo handles block filtering internally by querying user_blocks.
    const effectiveViewerId = input.viewerId ?? input.id;
    const aggregate = await this.reviews.aggregateForUser({
      ratedUserId: input.id,
      viewerId: effectiveViewerId,
    });

    // Round averageRating to 1 decimal place per spec.
    const averageRating =
      aggregate.averageRating !== null ? Math.round(aggregate.averageRating * 10) / 10 : null;

    return {
      user,
      isVerified,
      averageRating,
      reviewCount: aggregate.reviewCount,
      recentVisibleComments: aggregate.recentVisibleComments,
    };
  }
}
