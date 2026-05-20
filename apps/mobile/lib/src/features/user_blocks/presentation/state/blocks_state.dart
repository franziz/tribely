import 'package:equatable/equatable.dart';

import '../../domain/entities/blocked_user_summary.dart';
import '../../domain/entities/user_block_list_page.dart';

sealed class BlocksState extends Equatable {
  const BlocksState();

  @override
  List<Object?> get props => [];
}

class BlocksLoading extends BlocksState {
  const BlocksLoading();
}

class BlocksLoaded extends BlocksState {
  const BlocksLoaded({
    required this.page,
    this.isLoadingMore = false,
    this.paginationError,
  });

  final UserBlockListPage page;
  final bool isLoadingMore;
  final String? paginationError;

  List<BlockedUserSummary> get rows => page.rows;
  bool get hasMore => page.hasMore;

  BlocksLoaded copyWith({
    UserBlockListPage? page,
    bool? isLoadingMore,
    String? paginationError,
    bool clearPaginationError = false,
  }) {
    return BlocksLoaded(
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      paginationError: clearPaginationError
          ? null
          : (paginationError ?? this.paginationError),
    );
  }

  @override
  List<Object?> get props => [page, isLoadingMore, paginationError];
}

class BlocksEmpty extends BlocksState {
  const BlocksEmpty();
}

class BlocksFailure extends BlocksState {
  const BlocksFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
