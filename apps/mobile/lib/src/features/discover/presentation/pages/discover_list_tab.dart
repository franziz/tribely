import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/skeleton_loader.dart';
import '../controllers/discover_controller.dart';
import '../providers/discover_filter_providers.dart';
import '../providers/discover_providers.dart';
import '../state/discover_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/event_card.dart';

/// Infinite-scroll threshold: trigger loadMore() when scroll is within 600dp
/// of the bottom edge.
const double _kLoadMoreThreshold = 600.0;

/// Number of SkeletonEventCard instances shown during initial load per §H.
const int _kInitialSkeletonCount = 5;

/// Number of half-height shimmer placeholders shown during paginated loading
/// per §H.
const int _kPaginationSkeletonCount = 3;

/// List tab content widget for the Discover screen.
///
/// Exposes the scrollable event feed, filter chip row, empty / loading / error
/// states. D5's scaffold composes this inside an [IndexedStack].
///
/// Responsibilities:
/// - Infinite scroll via [NotificationListener<ScrollNotification>]:
///   calls [DiscoverController.loadMore()] when extentAfter < 600dp and state
///   is [DiscoverLoaded] with a non-null nextCursor.
/// - Loading: 5 [SkeletonEventCard] stacked at 12dp gap.
/// - Error (full-screen): [ErrorState] with Retry → controller.refresh().
/// - Error (after cached page): [ErrorState] appended below last real card.
/// - Empty: [EmptyState] per [DiscoverEmptyReason].
/// - Loaded: [EventCard] list + pagination loader footer.
class DiscoverListTab extends ConsumerWidget {
  const DiscoverListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoverControllerProvider);
    final controller = ref.read(discoverControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Content area ──
        // NOTE: FilterChipRow is hoisted to the DiscoverPage scaffold (D5) so
        // it persists across List/Map tab switches. Do NOT re-add it here.
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _maybeLoadMore(notification, state, controller);
              return false; // allow notification to bubble
            },
            child: _buildContent(context, ref, state, controller),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Content routing
  // ---------------------------------------------------------------------------

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DiscoverState state,
    DiscoverController controller,
  ) {
    return switch (state) {
      DiscoverInitial() || DiscoverLoading() => _buildInitialLoading(),
      DiscoverLoaded() => _buildLoadedList(state, controller),
      DiscoverEmpty() => _buildEmpty(ref, state),
      DiscoverError() => ErrorState(onRetry: controller.refresh),
    };
  }

  // ---------------------------------------------------------------------------
  // Initial loading — 5 SkeletonEventCard at 12dp gap (§H)
  // ---------------------------------------------------------------------------

  Widget _buildInitialLoading() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < _kInitialSkeletonCount; i++) ...[
            const SkeletonEventCard(),
            if (i < _kInitialSkeletonCount - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loaded list + pagination footer
  // ---------------------------------------------------------------------------

  Widget _buildLoadedList(DiscoverLoaded state, DiscoverController controller) {
    final events = state.events;
    final showPaginationLoader = state.isLoadingMore;
    final hasPaginationError = state.paginationError != null;

    // Footer slot count: skeletons during loading, +1 for the error widget when
    // a pagination failure occurred. Only one footer mode is active at a time.
    final footerCount = showPaginationLoader
        ? _kPaginationSkeletonCount
        : hasPaginationError
        ? 1
        : 0;
    final itemCount = events.length + footerCount;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 120), // space for sticky CTA
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index < events.length) {
          return EventCard(event: events[index]);
        }

        // Pagination footer region.
        if (hasPaginationError) {
          // Render inline error widget so the user can retry without losing
          // the already-loaded cards above.
          return ErrorState(onRetry: controller.loadMore);
        }

        // Skeleton placeholders during paginated loading (§H).
        final footerIndex = index - events.length;
        if (footerIndex == 0) {
          // Add top padding before pagination skeletons.
          return const Padding(
            padding: EdgeInsets.only(top: 4),
            child: _PaginationSkeleton(),
          );
        }
        return const _PaginationSkeleton();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmpty(WidgetRef ref, DiscoverEmpty state) {
    final filterNotifier = ref.read(discoverFilterControllerProvider.notifier);
    return EmptyState(reason: state.reason, filterNotifier: filterNotifier);
  }

  // ---------------------------------------------------------------------------
  // Infinite scroll trigger
  // ---------------------------------------------------------------------------

  void _maybeLoadMore(
    ScrollNotification notification,
    DiscoverState state,
    DiscoverController controller,
  ) {
    if (notification is! ScrollUpdateNotification) return;
    if (notification.metrics.extentAfter >= _kLoadMoreThreshold) return;
    if (state is! DiscoverLoaded) return;
    if (state.nextCursor == null) return;
    if (state.isLoadingMore) return;
    // Don't auto-trigger while an inline error footer is shown — the user must
    // press Retry explicitly to avoid an infinite retry loop on scroll.
    if (state.paginationError != null) return;

    controller.loadMore();
  }
}

// ---------------------------------------------------------------------------
// Half-height pagination skeleton (§H paginated loading footer)
// ---------------------------------------------------------------------------

/// Half-height shimmer card appended below real cards during paginated loading.
///
/// Uses [SkeletonLoader] for a simple rectangle that matches card width and
/// approximately half the typical card height (~100dp) without repeating the
/// full [SkeletonEventCard] silhouette (the real cards are still visible above).
class _PaginationSkeleton extends StatelessWidget {
  const _PaginationSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SkeletonLoader(
        width: double.infinity,
        height: 100,
        borderRadius: 16,
      ),
    );
  }
}
