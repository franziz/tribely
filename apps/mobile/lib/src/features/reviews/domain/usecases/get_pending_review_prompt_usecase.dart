import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/pending_review_prompt.dart';
import '../repositories/review_repository.dart';

/// Fetch the oldest eligible pending review prompt for the authenticated user.
///
/// GET /me/pending-review-prompts
///
/// Returns null when there are no prompts. All eligibility filtering is
/// server-side — mobile just renders what it receives.
class GetPendingReviewPromptUseCase
    implements UseCase<PendingReviewPrompt?, NoParams> {
  const GetPendingReviewPromptUseCase(this._repository);

  final ReviewRepository _repository;

  @override
  Future<Either<Failure, PendingReviewPrompt?>> call(NoParams params) =>
      _repository.getPendingReviewPrompt();
}
