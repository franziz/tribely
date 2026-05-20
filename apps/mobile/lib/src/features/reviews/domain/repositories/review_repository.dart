import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/pending_review_prompt.dart';
import '../entities/review.dart'; // used by submitReview
import '../entities/review_list_page.dart';

/// Abstract repository interface for the reviews domain.
///
/// All methods return [Either<Failure, T>] — the concrete implementation in
/// data/ catches [DioException] and maps it to the appropriate [Failure] subtype.
///
/// Pure Dart — no Flutter, no Dio, no Riverpod.
abstract class ReviewRepository {
  /// Submit a new review.
  ///
  /// POST /events/:eventId/reviews
  Future<Either<Failure, Review>> submitReview({
    required String eventId,
    required String ratedUserId,
    required int rating,
    String? comment,
  });

  /// Edit an existing review within the 24-hour edit window.
  ///
  /// PATCH /reviews/:reviewId — server responds 204 No Content on success.
  ///
  /// Returns [EditWindowExpiredFailure] when the server responds 409 with
  /// code `reviews.editWindowExpired`.
  Future<Either<Failure, void>> editReview({
    required String reviewId,
    required int rating,
    String? comment,
  });

  /// Paginated list of reviews visible on a user's public profile.
  ///
  /// GET /users/:userId/reviews
  Future<Either<Failure, ReviewListPage>> listReviewsForUser({
    required String userId,
    String? cursor,
    int limit = 20,
  });

  /// Paginated list of reviews the authenticated user has written, including
  /// hidden-author rows.
  ///
  /// GET /me/reviews/written
  Future<Either<Failure, ReviewListPage>> listReviewsWrittenByMe({
    String? cursor,
    int limit = 20,
  });

  /// Fetch the oldest eligible pending review prompt for the authenticated user.
  ///
  /// GET /me/pending-review-prompts
  ///
  /// Returns null when there are no pending prompts (the server returned
  /// `{ "prompt": null }`). All eligibility filtering (≥24h / ≤7d post-event,
  /// already-reviewed exclusion, blocked-user exclusion) is handled server-side.
  Future<Either<Failure, PendingReviewPrompt?>> getPendingReviewPrompt();
}
