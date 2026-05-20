import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/profile_review_aggregate.dart';
import '../../domain/entities/recent_review_comment.dart';
import '../../domain/entities/review_list_page.dart';
import '../../domain/entities/review_visibility.dart';
import '../../domain/usecases/list_reviews_for_user_usecase.dart';
import '../providers/review_providers.dart';
import '../state/profile_reviews_state.dart';

/// Loads and paginates reviews for a given user's profile.
///
/// Derives a [ProfileReviewAggregate] client-side from the first page of
/// results — averageRating, reviewCount, and up to 3 recent visible comments.
/// There is no dedicated aggregate endpoint in Phase 1.
///
/// Keyed by [userId] via autoDispose.family — each user profile gets its own
/// isolated state that is discarded when the widget leaves the tree.
class ProfileReviewsController extends Notifier<ProfileReviewsState> {
  ProfileReviewsController(this.userId);

  final String userId;

  @override
  ProfileReviewsState build() {
    Future(() => _load());
    return const ProfileReviewsLoading();
  }

  Future<void> _load() async {
    if (!ref.mounted) return;

    final useCase = ref.read(listReviewsForUserUseCaseProvider);
    final params = ListReviewsForUserParams(userId: userId, limit: 20);
    final result = await useCase(params);

    if (!ref.mounted) return;
    result.fold(
      (failure) => state = ProfileReviewsFailure(message: failure.message),
      (page) {
        if (page.rows.isEmpty) {
          state = const ProfileReviewsEmpty();
          return;
        }
        final aggregate = _buildAggregate(page);
        state = ProfileReviewsLoaded(aggregate: aggregate, reviewsPage: page);
      },
    );
  }

  /// Append next page of reviews.
  Future<void> loadMore() async {
    final current = state;
    if (current is! ProfileReviewsLoaded) return;
    if (!current.reviewsPage.hasMore) return;
    if (current.isLoadingMore) return;

    state = current.copyWith(isLoadingMore: true);

    final useCase = ref.read(listReviewsForUserUseCaseProvider);
    final params = ListReviewsForUserParams(
      userId: userId,
      cursor: current.reviewsPage.nextCursor,
      limit: 20,
    );
    final result = await useCase(params);

    if (!ref.mounted) return;
    result.fold(
      (failure) {
        state = current.copyWith(
          isLoadingMore: false,
          paginationError: failure.message,
        );
      },
      (nextPage) {
        final merged = ReviewListPage(
          rows: [...current.reviewsPage.rows, ...nextPage.rows],
          nextCursor: nextPage.nextCursor,
        );
        state = current.copyWith(reviewsPage: merged, isLoadingMore: false);
      },
    );
  }

  /// Refresh from the first page.
  Future<void> refresh() async {
    state = const ProfileReviewsLoading();
    await _load();
  }

  // ---------------------------------------------------------------------------
  // Aggregate derivation
  //
  // The API does not expose a dedicated aggregate endpoint in Phase 1.
  // We compute it client-side from the first page.
  // ---------------------------------------------------------------------------

  ProfileReviewAggregate _buildAggregate(ReviewListPage page) {
    final visibleRatings = <int>[];
    final recentComments = <RecentReviewComment>[];

    for (final row in page.rows) {
      if (row is ReviewVisible) {
        visibleRatings.add(row.review.rating);
        if (row.review.comment != null && recentComments.length < 3) {
          recentComments.add(
            RecentReviewComment(
              excerpt: row.review.comment!,
              raterDisplayName: row
                  .review
                  .raterUserId, // display name not in Phase 1 response
              rating: row.review.rating,
              eventTitle:
                  row.review.eventId, // event title not in Phase 1 response
              createdAt: row.review.createdAt,
            ),
          );
        }
      }
    }

    if (visibleRatings.isEmpty) {
      return const ProfileReviewAggregate(
        reviewCount: 0,
        recentVisibleComments: [],
      );
    }

    final avg = visibleRatings.reduce((a, b) => a + b) / visibleRatings.length;

    return ProfileReviewAggregate(
      averageRating: avg,
      reviewCount: visibleRatings.length,
      recentVisibleComments: recentComments,
    );
  }
}
