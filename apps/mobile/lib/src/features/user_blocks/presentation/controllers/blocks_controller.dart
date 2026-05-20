import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user_block_list_page.dart';
import '../../domain/usecases/list_my_blocks_usecase.dart';
import '../../domain/usecases/unblock_user_usecase.dart';
import '../providers/user_block_providers.dart';
import '../state/blocks_state.dart';

/// Owns the state for the Blocked Users page.
///
/// Loads the first page on construction. Supports pagination via [loadMore]
/// and optimistic row removal via [unblock].
class BlocksController extends Notifier<BlocksState> {
  @override
  BlocksState build() {
    Future(() => _load());
    return const BlocksLoading();
  }

  Future<void> _load() async {
    if (!ref.mounted) return;

    final useCase = ref.read(listMyBlocksUseCaseProvider);
    const params = ListMyBlocksParams(limit: 20);
    final result = await useCase(params);

    if (!ref.mounted) return;
    result.fold((failure) => state = BlocksFailure(message: failure.message), (
      page,
    ) {
      if (page.rows.isEmpty) {
        state = const BlocksEmpty();
        return;
      }
      state = BlocksLoaded(page: page);
    });
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! BlocksLoaded) return;
    if (!current.hasMore) return;
    if (current.isLoadingMore) return;

    state = current.copyWith(isLoadingMore: true, clearPaginationError: true);

    final useCase = ref.read(listMyBlocksUseCaseProvider);
    final params = ListMyBlocksParams(
      cursor: current.page.nextCursor,
      limit: 20,
    );
    final result = await useCase(params);

    if (!ref.mounted) return;
    result.fold(
      (failure) {
        state = current.copyWith(
          isLoadingMore: false,
          paginationError: failure.message,
        );
      },
      (nextPage) {
        final merged = UserBlockListPage(
          rows: [...current.page.rows, ...nextPage.rows],
          nextCursor: nextPage.nextCursor,
        );
        state = current.copyWith(page: merged, isLoadingMore: false);
      },
    );
  }

  /// Optimistically removes the row for [blockedUserId], then calls the
  /// unblock use case. If the API call fails the row is restored and an
  /// inline error is surfaced via [BlocksLoaded.paginationError].
  Future<void> unblock(String blockedUserId) async {
    final current = state;
    if (current is! BlocksLoaded) return;

    // Optimistic removal
    final updatedRows = current.page.rows
        .where((r) => r.blockedUserId != blockedUserId)
        .toList();
    final updatedPage = UserBlockListPage(
      rows: updatedRows,
      nextCursor: current.page.nextCursor,
    );
    state = updatedRows.isEmpty
        ? const BlocksEmpty()
        : current.copyWith(page: updatedPage, clearPaginationError: true);

    final useCase = ref.read(unblockUserUseCaseProvider);
    final result = await useCase(
      UnblockUserParams(blockedUserId: blockedUserId),
    );

    if (!ref.mounted) return;
    result.fold(
      (failure) {
        // Restore the previous state on failure.
        state = BlocksLoaded(
          page: current.page,
          paginationError: failure.message,
        );
      },
      (_) {
        /* optimistic removal confirmed */
      },
    );
  }

  Future<void> refresh() async {
    state = const BlocksLoading();
    await _load();
  }
}
