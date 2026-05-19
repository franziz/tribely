import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/review_list_page.dart';
import '../repositories/review_repository.dart';

class ListReviewsWrittenByMeParams extends Equatable {
  const ListReviewsWrittenByMeParams({this.cursor, this.limit = 20});

  final String? cursor;
  final int limit;

  @override
  List<Object?> get props => [cursor, limit];
}

/// List reviews the authenticated user has written (outbound reviews).
///
/// GET /me/reviews/written
/// Includes [ReviewHidden] rows so the author can see their own moderated
/// content and the hidden-author notice.
class ListReviewsWrittenByMeUseCase
    implements UseCase<ReviewListPage, ListReviewsWrittenByMeParams> {
  const ListReviewsWrittenByMeUseCase(this._repository);
  final ReviewRepository _repository;

  @override
  Future<Either<Failure, ReviewListPage>> call(
    ListReviewsWrittenByMeParams params,
  ) => _repository.listReviewsWrittenByMe(
    cursor: params.cursor,
    limit: params.limit,
  );
}
