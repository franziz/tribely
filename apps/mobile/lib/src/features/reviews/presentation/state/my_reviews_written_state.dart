import 'package:equatable/equatable.dart';

import '../../domain/entities/review_list_page.dart';

/// State for the "Reviews I wrote" page.
sealed class MyReviewsWrittenState extends Equatable {
  const MyReviewsWrittenState();
}

final class MyReviewsWrittenLoading extends MyReviewsWrittenState {
  const MyReviewsWrittenLoading();

  @override
  List<Object?> get props => [];
}

final class MyReviewsWrittenLoaded extends MyReviewsWrittenState {
  const MyReviewsWrittenLoaded({
    required this.page,
    this.isLoadingMore = false,
    this.paginationError,
  });

  final ReviewListPage page;
  final bool isLoadingMore;
  final String? paginationError;

  MyReviewsWrittenLoaded copyWith({
    ReviewListPage? page,
    bool? isLoadingMore,
    String? paginationError,
  }) => MyReviewsWrittenLoaded(
    page: page ?? this.page,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    paginationError: paginationError,
  );

  @override
  List<Object?> get props => [page, isLoadingMore, paginationError];
}

final class MyReviewsWrittenEmpty extends MyReviewsWrittenState {
  const MyReviewsWrittenEmpty();

  @override
  List<Object?> get props => [];
}

final class MyReviewsWrittenFailure extends MyReviewsWrittenState {
  const MyReviewsWrittenFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
