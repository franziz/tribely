import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/review_list_page.dart';
import '../../domain/entities/review_visibility.dart';
import '../providers/review_providers.dart';
import '../state/my_reviews_written_state.dart';
import '../string_assets/review_copy.dart';
import '../widgets/hidden_review_author_notice.dart';
import '../widgets/review_row.dart';

/// "Reviews I wrote" page — shows all outbound reviews written by the
/// authenticated user, including hidden-author rows.
///
/// Route path: /profile/reviews-written
/// Full-screen on root navigator (no bottom nav bar).
class MyReviewsWrittenPage extends ConsumerWidget {
  const MyReviewsWrittenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    final state = ref.watch(myReviewsWrittenControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Reviews I Wrote', style: TribelyType.headline(ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: switch (state) {
        MyReviewsWrittenLoading() => const _LoadingBody(),
        MyReviewsWrittenEmpty() => _EmptyBody(inkSecondary: inkSecondary),
        MyReviewsWrittenFailure(:final message) => _ErrorBody(
          message: message,
          inkSecondary: inkSecondary,
          onRetry: () =>
              ref.read(myReviewsWrittenControllerProvider.notifier).refresh(),
        ),
        MyReviewsWrittenLoaded(
          :final page,
          :final isLoadingMore,
          :final paginationError,
        ) =>
          _LoadedBody(
            page: page,
            isLoadingMore: isLoadingMore,
            paginationError: paginationError,
            onLoadMore: () => ref
                .read(myReviewsWrittenControllerProvider.notifier)
                .loadMore(),
            ink: ink,
            inkSecondary: inkSecondary,
          ),
      },
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SkeletonLoader(width: double.infinity, height: 80, borderRadius: 12),
          SizedBox(height: 12),
          SkeletonLoader(width: double.infinity, height: 80, borderRadius: 12),
          SizedBox(height: 12),
          SkeletonLoader(width: double.infinity, height: 80, borderRadius: 12),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.inkSecondary});
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        ReviewCopy.noReviewsYet,
        style: TribelyType.italicCaption(inkSecondary),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.inkSecondary,
    required this.onRetry,
  });
  final String message;
  final Color inkSecondary;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              style: TribelyType.bodyM(inkSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.page,
    required this.isLoadingMore,
    required this.paginationError,
    required this.onLoadMore,
    required this.ink,
    required this.inkSecondary,
  });

  final ReviewListPage page;
  final bool isLoadingMore;
  final String? paginationError;
  final VoidCallback onLoadMore;
  final Color ink;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    final rows = page.rows;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: rows.length + (isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final row = rows[index];
          return switch (row) {
            ReviewVisible(:final review) => _AuthorReviewRow(
              review: review,
              ink: ink,
              inkSecondary: inkSecondary,
            ),
            ReviewHidden(:final review) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AuthorReviewRow(
                  review: review,
                  ink: ink,
                  inkSecondary: inkSecondary,
                ),
                const SizedBox(height: 8),
                const HiddenReviewAuthorNotice(),
              ],
            ),
            ReviewBlindMutualPending() => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

class _AuthorReviewRow extends StatelessWidget {
  const _AuthorReviewRow({
    required this.review,
    required this.ink,
    required this.inkSecondary,
  });

  final Review review;
  final Color ink;
  final Color inkSecondary;

  bool get _canEdit => DateTime.now().difference(review.createdAt).inHours < 24;

  @override
  Widget build(BuildContext context) {
    return ReviewRow(
      review: review,
      onOverflowTap: () {
        // TODO: import ReportReviewSheet from reports/ when Brief 2B lands
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report sheet coming in Brief 2B')),
        );
      },
      showEditLink: _canEdit,
      onEditTap: _canEdit
          ? () {
              context.navigateToEditReview(review);
            }
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation helper (avoids importing go_router here; the page decouples from
// routing by accepting a callback instead. Declared as a BuildContext extension
// so it's overridable in tests.)
// ---------------------------------------------------------------------------

extension _ReviewNavigation on BuildContext {
  void navigateToEditReview(Review review) {
    // Route is mounted in app_router.dart; push with query params.
    // Using Navigator.of for simplicity — the route handles the params.
    Navigator.of(this).pushNamed(
      '/reviews/write',
      arguments: {
        'reviewId': review.id,
        'eventId': review.eventId,
        'ratedUserId': review.ratedUserId,
        'prefillRating': review.rating,
        'prefillComment': review.comment,
        'reviewCreatedAt': review.createdAt.toIso8601String(),
      },
    );
  }
}
