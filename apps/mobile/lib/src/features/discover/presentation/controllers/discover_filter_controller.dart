import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/discover_filters.dart';
import '../../../events/domain/entities/event_category.dart';
import '../state/discover_filter_state.dart';

/// Owns the active [DiscoverFiltersActive] state for the Discover feed.
///
/// Mutation surface:
///   - [setTimeWindow] — single-select (radio-like); replaces previous value.
///   - [toggleCategory] — multi-select toggle (OR semantics); selecting an
///     already-selected category removes it.
///   - [setMaxDistanceKm] — single-select chip set; null clears the filter.
///     Null ≠ "location not granted" — permission visibility is D3/D4's job.
///   - [reset] — returns to initial state (anytime, no categories, no distance).
///
/// Debouncing is NOT done inside this controller — it is the responsibility of
/// [debouncedFiltersProvider] in `discover_filter_providers.dart`, which wraps
/// this controller's state stream and applies a 250ms debounce.
/// D2's DiscoverController MUST subscribe to [debouncedFiltersProvider], not
/// to this controller's raw Riverpod state, to avoid spurious network calls on
/// every chip tap.
class DiscoverFilterController extends Notifier<DiscoverFilterState> {
  @override
  DiscoverFilterState build() {
    return const DiscoverFiltersActive();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Replaces the current time window. Single-select — only one value active
  /// at a time (radio-like per §B Filter Chip Row spec).
  void setTimeWindow(TimeWindow timeWindow) {
    final current = state;
    if (current is! DiscoverFiltersActive) return;
    if (current.timeWindow == timeWindow) return;

    state = current.copyWith(timeWindow: timeWindow);
  }

  /// Toggles [category] membership in the active set.
  ///
  /// Multi-select OR semantics per §B Filter Chip Row spec:
  ///   - Absent → added.
  ///   - Present → removed.
  void toggleCategory(EventCategory category) {
    final current = state;
    if (current is! DiscoverFiltersActive) return;

    final updated = Set<EventCategory>.from(current.categories);
    if (updated.contains(category)) {
      updated.remove(category);
    } else {
      updated.add(category);
    }

    state = current.copyWith(categories: updated);
  }

  /// Sets the maximum distance radius in kilometres.
  ///
  /// Pass null to clear the distance filter. The D3/D4 layer controls whether
  /// the distance chip row is visible (requires location permission); this
  /// controller is intentionally agnostic to permission state.
  void setMaxDistanceKm(double? maxDistanceKm) {
    final current = state;
    if (current is! DiscoverFiltersActive) return;
    if (current.maxDistanceKm == maxDistanceKm) return;

    state = current.copyWith(maxDistanceKm: maxDistanceKm);
  }

  /// Resets all filters to their initial values:
  ///   - [TimeWindow.anytime]
  ///   - No categories (all categories shown)
  ///   - No distance filter
  void reset() {
    state = const DiscoverFiltersActive();
  }
}
