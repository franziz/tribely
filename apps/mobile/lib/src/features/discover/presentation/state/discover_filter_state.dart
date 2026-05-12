import '../../domain/entities/discover_filters.dart';
import '../../../events/domain/entities/event_category.dart';

/// Sealed state for [DiscoverFilterController].
///
/// Single concrete subclass for now; the seal is future-proofing for a
/// potential DiscoverFilterLoading or DiscoverFilterError subclass if the
/// filter surface grows (e.g., server-side constraint loading).
sealed class DiscoverFilterState {
  const DiscoverFilterState();
}

/// The active user-selected filters for the Discover feed.
///
/// Initial values match the acceptance criteria:
///   - [timeWindow] = [TimeWindow.anytime]
///   - [categories] = empty set (all categories)
///   - [maxDistanceKm] = null (no distance filter)
///
/// This class is intentionally thin — it mirrors the fields that
/// [DiscoverFilterController] exposes as mutation surface. Full query
/// construction (lat/lng, cursor, limit) happens in D2's DiscoverController.
final class DiscoverFiltersActive extends DiscoverFilterState {
  const DiscoverFiltersActive({
    this.timeWindow = TimeWindow.anytime,
    this.categories = const {},
    this.maxDistanceKm,
  });

  final TimeWindow timeWindow;

  /// Selected categories. Empty = all categories (param omitted from API call).
  final Set<EventCategory> categories;

  /// Selected distance radius in km. Null = no distance filter.
  final double? maxDistanceKm;

  DiscoverFiltersActive copyWith({
    TimeWindow? timeWindow,
    Set<EventCategory>? categories,
    Object? maxDistanceKm = _sentinel,
  }) {
    return DiscoverFiltersActive(
      timeWindow: timeWindow ?? this.timeWindow,
      categories: categories ?? this.categories,
      maxDistanceKm:
          maxDistanceKm == _sentinel
              ? this.maxDistanceKm
              : maxDistanceKm as double?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverFiltersActive &&
          runtimeType == other.runtimeType &&
          timeWindow == other.timeWindow &&
          _setsEqual(categories, other.categories) &&
          maxDistanceKm == other.maxDistanceKm;

  @override
  int get hashCode => Object.hash(timeWindow, categories, maxDistanceKm);

  // Helpers
  static bool _setsEqual(
    Set<EventCategory> a,
    Set<EventCategory> b,
  ) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

// Sentinel for copyWith nullable-field overrides.
const Object _sentinel = Object();
