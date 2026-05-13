import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/location_service_providers.dart';
import '../../domain/entities/discover_filters.dart';
import '../../domain/usecases/browse_events_usecase.dart';
import '../../../../core/providers/browse_events_usecase_provider.dart';
import '../providers/discover_filter_providers.dart';
import '../state/discover_filter_state.dart';
import '../state/discover_state.dart';

/// Primary controller for the Discover screen.
///
/// Responsibilities:
///   - Watches [debouncedFiltersProvider] and triggers a full refetch on every
///     new filter snapshot.
///   - Manages cursor-based pagination state: loading / loaded / empty / error.
///   - Exposes [loadMore()] for the infinite-scroll trigger in D3.
///   - Exposes [refresh()] for D3's error-state Retry button.
///
/// Design notes:
///   - List and map views share this single controller — the list/map toggle is
///     a UI concern (D5) that does NOT require separate state.
///   - Location is resolved per-fetch when [DiscoverFiltersActive.maxDistanceKm]
///     is set. If the position is unavailable the distance filter is silently
///     dropped for that fetch only; D1's filter state is NOT mutated.
///   - [loadMore()] is race-safe: it guards on [DiscoverLoaded.isLoadingMore]
///     and [DiscoverLoaded.nextCursor] before issuing the next request.
class DiscoverController extends Notifier<DiscoverState> {
  @override
  DiscoverState build() {
    // React to debounced filter changes — triggers a full refetch from cursor=null.
    ref.listen<AsyncValue<DiscoverFiltersActive>>(debouncedFiltersProvider, (
      _,
      next,
    ) {
      next.whenData((_) => _fetchFirstPage());
    });

    // Kick off the initial fetch using the current (default) filter state.
    Future(() => _fetchFirstPage());
    return const DiscoverLoading();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Append the next page of results.
  ///
  /// No-op when:
  ///   - State is not [DiscoverLoaded].
  ///   - [DiscoverLoaded.nextCursor] is null (end of stream).
  ///   - [DiscoverLoaded.isLoadingMore] is true (request already in flight).
  Future<void> loadMore() async {
    final current = state;
    if (current is! DiscoverLoaded) return;
    if (current.isLoadingMore) return;
    if (current.nextCursor == null) return;

    state = current.copyWith(isLoadingMore: true);

    final filters = _currentFilterState();
    final (resolvedFilters, dropped) = await _resolveFilters(
      filters,
      cursor: current.nextCursor,
    );

    if (!ref.mounted) return;

    final useCase = ref.read(browseEventsUseCaseProvider);
    final params = BrowseEventsParams(filters: resolvedFilters);
    final result = await useCase(params);

    if (!ref.mounted) return;

    // Re-read state after await — it may have been reset by a concurrent filter
    // change. Only append if still in a DiscoverLoaded state with the same
    // nextCursor we started from to prevent double-append.
    final postAwaitState = state;
    if (postAwaitState is! DiscoverLoaded) return;
    if (postAwaitState.nextCursor != current.nextCursor) return;

    state = result.fold(
      (failure) {
        // On loadMore failure preserve existing results and surface the error
        // as an inline footer. Reset isLoadingMore so D3 can show the retry
        // widget rather than a spinner.
        return postAwaitState.copyWith(
          isLoadingMore: false,
          paginationError: failure,
        );
      },
      (page) => DiscoverLoaded(
        events: [...postAwaitState.events, ...page.events],
        nextCursor: page.nextCursor,
        isLoadingMore: false,
        distanceFilterDropped: dropped,
        // paginationError is null by default — clears any prior error.
      ),
    );
  }

  /// Full refetch from cursor=null. Intended for D3's error-state Retry button
  /// and for any caller that needs a clean reload (e.g., pull-to-refresh later).
  Future<void> refresh() => _fetchFirstPage();

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _fetchFirstPage() async {
    if (!ref.mounted) return;
    state = const DiscoverLoading();

    final filters = _currentFilterState();
    final (resolvedFilters, dropped) = await _resolveFilters(filters);

    if (!ref.mounted) return;

    final useCase = ref.read(browseEventsUseCaseProvider);
    final params = BrowseEventsParams(filters: resolvedFilters);
    final result = await useCase(params);

    if (!ref.mounted) return;

    state = result.fold(DiscoverError.new, (page) {
      if (page.events.isEmpty) {
        return DiscoverEmpty(_emptyReason(filters));
      }
      return DiscoverLoaded(
        events: page.events,
        nextCursor: page.nextCursor,
        distanceFilterDropped: dropped,
      );
    });
  }

  /// Resolves the [DiscoverFiltersActive] from D1 into a [DiscoverFilters] for
  /// the use case, optionally merging [cursor] for pagination.
  ///
  /// When [DiscoverFiltersActive.maxDistanceKm] is set, fetches the device
  /// position via [locationServiceProvider]. If the position is null (denied /
  /// timeout), the distance filter is dropped for this fetch only and the
  /// returned bool is true (distanceFilterDropped).
  Future<(DiscoverFilters, bool)> _resolveFilters(
    DiscoverFiltersActive activeFilters, {
    String? cursor,
  }) async {
    double? maxDistanceKm = activeFilters.maxDistanceKm;
    double? lat;
    double? lng;
    var dropped = false;

    if (maxDistanceKm != null) {
      final locationService = ref.read(locationServiceProvider);
      final LatLng? position = await locationService.currentPosition();

      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
      } else {
        // Location unavailable — drop the distance filter for this fetch only.
        // D1's filter state is intentionally NOT mutated.
        maxDistanceKm = null;
        dropped = true;
      }
    }

    final filters = DiscoverFilters(
      timeWindow: activeFilters.timeWindow,
      categories: activeFilters.categories,
      maxDistanceKm: maxDistanceKm,
      lat: lat,
      lng: lng,
      cursor: cursor,
    );

    return (filters, dropped);
  }

  /// Reads the current filter state from D1's controller directly (not the
  /// debounced stream) so that [refresh()] and [loadMore()] always use the
  /// most up-to-date filter values at call time.
  DiscoverFiltersActive _currentFilterState() {
    final filterState = ref.read(discoverFilterControllerProvider);
    // filterState is always DiscoverFiltersActive in the current D1 design
    // (single concrete subclass of DiscoverFilterState). The cast is safe;
    // future subclasses would need to be handled here.
    return filterState as DiscoverFiltersActive;
  }

  /// Determines the appropriate [DiscoverEmptyReason] based on whether any
  /// filter is non-default at the time the empty result was returned.
  ///
  /// Default filter state (per D1 initial values):
  ///   timeWindow == anytime, categories == {}, maxDistanceKm == null.
  DiscoverEmptyReason _emptyReason(DiscoverFiltersActive filters) {
    final isDefault =
        filters.timeWindow == TimeWindow.anytime &&
        filters.categories.isEmpty &&
        filters.maxDistanceKm == null;

    return isDefault
        ? DiscoverEmptyReason.noEventsInArea
        : DiscoverEmptyReason.noEventsMatchFilters;
  }
}
