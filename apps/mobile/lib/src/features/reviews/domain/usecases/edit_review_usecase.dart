import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/review_repository.dart';

class EditReviewParams extends Equatable {
  const EditReviewParams({
    required this.reviewId,
    required this.rating,
    this.comment,
  });

  final String reviewId;
  final int rating;
  final String? comment;

  @override
  List<Object?> get props => [reviewId, rating, comment];
}

/// Edit an existing review within its 24-hour edit window.
///
/// PATCH /reviews/:reviewId — server responds 204 No Content on success.
///
/// The server enforces the window and returns 409 with code
/// `reviews.editWindowExpired` when the window has closed. The data layer maps
/// this to [EditWindowExpiredFailure]; the controller renders the lock banner.
///
/// Note: The server returns 204 (no body), so the use case returns void on
/// success. The calling controller retains the pre-edit local state for display.
class EditReviewUseCase implements UseCase<void, EditReviewParams> {
  const EditReviewUseCase(this._repository);
  final ReviewRepository _repository;

  @override
  Future<Either<Failure, void>> call(EditReviewParams params) =>
      _repository.editReview(
        reviewId: params.reviewId,
        rating: params.rating,
        comment: params.comment,
      );
}
