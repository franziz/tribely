import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/review_list_page.dart';
import '../repositories/review_repository.dart';

class ListReviewsForUserParams extends Equatable {
  const ListReviewsForUserParams({
    required this.userId,
    this.cursor,
    this.limit = 20,
  });

  final String userId;
  final String? cursor;
  final int limit;

  @override
  List<Object?> get props => [userId, cursor, limit];
}

/// List reviews visible on a user's public profile.
///
/// GET /users/:userId/reviews
/// The server applies the mutual-window projection and block filter before
/// returning; the data layer translates the discriminator into [ReviewVisibility].
class ListReviewsForUserUseCase
    implements UseCase<ReviewListPage, ListReviewsForUserParams> {
  const ListReviewsForUserUseCase(this._repository);
  final ReviewRepository _repository;

  @override
  Future<Either<Failure, ReviewListPage>> call(
    ListReviewsForUserParams params,
  ) => _repository.listReviewsForUser(
    userId: params.userId,
    cursor: params.cursor,
    limit: params.limit,
  );
}
