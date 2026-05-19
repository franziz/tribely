import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/review.dart';
import '../../domain/usecases/edit_review_usecase.dart';
import '../../domain/usecases/submit_review_usecase.dart';
import '../providers/review_providers.dart';
import '../state/review_composer_state.dart';

/// Owns the state for the review composer screen (submit + edit flows).
///
/// Keyed by a composite family key so the same route can be reused for both
/// new submissions and edits. Disposes when the page is popped.
///
/// Responsibilities:
///   - [submit]: POST /events/:eventId/reviews — Idle → Submitting → Success|Failure
///   - [edit]: PATCH /reviews/:reviewId — Idle → Submitting → Success|Failure
///   - [reset]: returns to Idle after the caller acknowledges an error
class ReviewComposerController extends Notifier<ReviewComposerState> {
  @override
  ReviewComposerState build() => const ReviewComposerIdle();

  /// Submit a new review.
  ///
  /// [existingReviewForSuccess] is an optional pre-built [Review] to carry
  /// into [ReviewComposerSuccess] so the post-submit confirmation can display
  /// reviewer data without requiring a separate fetch.
  Future<void> submit({
    required String eventId,
    required String ratedUserId,
    required int rating,
    String? comment,
  }) async {
    if (state is ReviewComposerSubmitting) return;
    state = const ReviewComposerSubmitting();

    final useCase = ref.read(submitReviewUseCaseProvider);
    final params = SubmitReviewParams(
      eventId: eventId,
      ratedUserId: ratedUserId,
      rating: rating,
      comment: comment,
    );
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) =>
          ReviewComposerFailure(message: failure.message, code: failure.code),
      (review) => ReviewComposerSuccess(review: review),
    );
  }

  /// Edit an existing review within the 24-hour window.
  ///
  /// [originalReview] is the pre-edit [Review] used to construct a local
  /// [ReviewComposerSuccess] on success (the server returns 204 no-body).
  Future<void> edit({
    required String reviewId,
    required int rating,
    String? comment,
    required Review originalReview,
  }) async {
    if (state is ReviewComposerSubmitting) return;
    state = const ReviewComposerSubmitting();

    final useCase = ref.read(editReviewUseCaseProvider);
    final params = EditReviewParams(
      reviewId: reviewId,
      rating: rating,
      comment: comment,
    );
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) =>
          ReviewComposerFailure(message: failure.message, code: failure.code),
      (_) => ReviewComposerSuccess(
        review: originalReview.copyWith(rating: rating, comment: comment),
      ),
    );
  }

  /// Returns to [ReviewComposerIdle].
  void reset() {
    state = const ReviewComposerIdle();
  }
}
