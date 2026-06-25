import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/review_eligibility.dart';
import '../repositories/review_repository.dart';

class GetReviewEligibilityParams extends Equatable {
  const GetReviewEligibilityParams({required this.eventId});

  final String eventId;

  @override
  List<Object?> get props => [eventId];
}

/// Check whether the current user is eligible to write a review for the
/// host of a specific event.
///
/// GET /events/:eventId/review-eligibility
///
/// The endpoint always returns 200 — ineligibility is expressed via
/// [ReviewEligibility.eligible] == false, never via an error status.
class GetReviewEligibilityUseCase
    implements UseCase<ReviewEligibility, GetReviewEligibilityParams> {
  const GetReviewEligibilityUseCase(this._repository);

  final ReviewRepository _repository;

  @override
  Future<Either<Failure, ReviewEligibility>> call(
    GetReviewEligibilityParams params,
  ) => _repository.getReviewEligibility(eventId: params.eventId);
}
