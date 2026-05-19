import type { User } from '../../domain/entities/user.js';
import type { ReviewAggregateForUser } from '@/features/reviews/domain/repositories/review.repository.js';

export type GetUserResult = {
  user: User;
  isVerified: boolean;
  averageRating: number | null;
  reviewCount: number;
  recentVisibleComments: ReviewAggregateForUser['recentVisibleComments'];
};
