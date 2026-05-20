import 'package:equatable/equatable.dart';

import '../../domain/entities/profile_review_aggregate.dart';
import '../../domain/entities/review_list_page.dart';

/// State for the profile reviews section (aggregate + paginated review list).
sealed class ProfileReviewsState extends Equatable {
  const ProfileReviewsState();
}

final class ProfileReviewsLoading extends ProfileReviewsState {
  const ProfileReviewsLoading();

  @override
  List<Object?> get props => [];
}

final class ProfileReviewsLoaded extends ProfileReviewsState {
  const ProfileReviewsLoaded({
    required this.aggregate,
    required this.reviewsPage,
    this.isLoadingMore = false,
    this.paginationError,
  });

  final ProfileReviewAggregate aggregate;
  final ReviewListPage reviewsPage;
  final bool isLoadingMore;
  final String? paginationError;

  ProfileReviewsLoaded copyWith({
    ProfileReviewAggregate? aggregate,
    ReviewListPage? reviewsPage,
    bool? isLoadingMore,
    String? paginationError,
  }) => ProfileReviewsLoaded(
    aggregate: aggregate ?? this.aggregate,
    reviewsPage: reviewsPage ?? this.reviewsPage,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    paginationError: paginationError,
  );

  @override
  List<Object?> get props => [
    aggregate,
    reviewsPage,
    isLoadingMore,
    paginationError,
  ];
}

final class ProfileReviewsEmpty extends ProfileReviewsState {
  const ProfileReviewsEmpty();

  @override
  List<Object?> get props => [];
}

final class ProfileReviewsFailure extends ProfileReviewsState {
  const ProfileReviewsFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
