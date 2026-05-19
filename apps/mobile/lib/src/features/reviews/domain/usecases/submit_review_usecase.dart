import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/review.dart';
import '../repositories/review_repository.dart';

class SubmitReviewParams extends Equatable {
  const SubmitReviewParams({
    required this.eventId,
    required this.ratedUserId,
    required this.rating,
    this.comment,
  });

  final String eventId;
  final String ratedUserId;
  final int rating;
  final String? comment;

  @override
  List<Object?> get props => [eventId, ratedUserId, rating, comment];
}

/// Submit a new review for another user following a shared event.
///
/// POST /events/:eventId/reviews
/// Validation (rating bounds, comment length) lives in [ReviewInputValidator];
/// this use case delegates to the repository without re-validating.
class SubmitReviewUseCase implements UseCase<Review, SubmitReviewParams> {
  const SubmitReviewUseCase(this._repository);
  final ReviewRepository _repository;

  @override
  Future<Either<Failure, Review>> call(SubmitReviewParams params) =>
      _repository.submitReview(
        eventId: params.eventId,
        ratedUserId: params.ratedUserId,
        rating: params.rating,
        comment: params.comment,
      );
}
