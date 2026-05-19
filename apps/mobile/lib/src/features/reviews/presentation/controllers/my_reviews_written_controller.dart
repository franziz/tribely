import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/review_list_page.dart';
import '../../domain/usecases/list_reviews_written_by_me_usecase.dart';
import '../providers/review_providers.dart';
import '../state/my_reviews_written_state.dart';

/// Paginates the authenticated user's outbound reviews ("Reviews I wrote").
///
/// Loads the first page on construction. Keyed via autoDispose so the state
/// is discarded when the page leaves the tree.
class MyReviewsWrittenController extends Notifier<MyReviewsWrittenState> {
  @override
  MyReviewsWrittenState build() {
    Future(() => _load());
    return const MyReviewsWrittenLoading();
  }

  Future<void> _load() async {
    if (!ref.mounted) return;

    final useCase = ref.read(listReviewsWrittenByMeUseCaseProvider);
    final result = await useCase(const ListReviewsWrittenByMeParams(limit: 20));

    if (!ref.mounted) return;
    result.fold(
      (failure) => state = MyReviewsWrittenFailure(message: failure.message),
      (page) {
        if (page.rows.isEmpty) {
          state = const MyReviewsWrittenEmpty();
          return;
        }
        state = MyReviewsWrittenLoaded(page: page);
      },
    );
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! MyReviewsWrittenLoaded) return;
    if (!current.page.hasMore) return;
    if (current.isLoadingMore) return;

    state = current.copyWith(isLoadingMore: true);

    final useCase = ref.read(listReviewsWrittenByMeUseCaseProvider);
    final result = await useCase(
      ListReviewsWrittenByMeParams(cursor: current.page.nextCursor, limit: 20),
    );

    if (!ref.mounted) return;
    result.fold(
      (failure) {
        state = current.copyWith(
          isLoadingMore: false,
          paginationError: failure.message,
        );
      },
      (nextPage) {
        final merged = ReviewListPage(
          rows: [...current.page.rows, ...nextPage.rows],
          nextCursor: nextPage.nextCursor,
        );
        state = current.copyWith(page: merged, isLoadingMore: false);
      },
    );
  }

  Future<void> refresh() async {
    state = const MyReviewsWrittenLoading();
    await _load();
  }
}
