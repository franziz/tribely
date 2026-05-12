import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../events/domain/entities/event.dart';

// ---------------------------------------------------------------------------
// Empty-state reason enum
// ---------------------------------------------------------------------------

/// Distinguishes the two empty-state flavors from designer §G.
///
/// The controller encodes which flavor applies so the view can pick the right
/// copy without re-implementing the filter-default logic.
///
/// - [noEventsInArea]          — default filters, API returned zero results.
///   "There are no events near you yet — be the first to create one!"
/// - [noEventsMatchFilters]    — non-default filters, API returned zero results.
///   "No events match your filters — try widening your search."
enum DiscoverEmptyReason { noEventsInArea, noEventsMatchFilters }

// ---------------------------------------------------------------------------
// Sealed state hierarchy
// ---------------------------------------------------------------------------

/// Sealed state for [DiscoverController].
///
/// Transitions:
///   build()              → [DiscoverLoading]
///   use case succeeds    → [DiscoverLoaded] or [DiscoverEmpty]
///   use case fails       → [DiscoverError]
///   filter change        → back to [DiscoverLoading] (full refetch)
///   loadMore() appending → [DiscoverLoaded] with isLoadingMore=true while in
///                          flight, then updated [DiscoverLoaded] on completion
sealed class DiscoverState extends Equatable {
  const DiscoverState();

  @override
  List<Object?> get props => [];
}

/// Emitted before the first page has been fetched (controller build phase) or
/// whenever filters change and a full refetch is in flight.
class DiscoverInitial extends DiscoverState {
  const DiscoverInitial();
}

/// First-page fetch in flight. No results are available yet.
class DiscoverLoading extends DiscoverState {
  const DiscoverLoading();
}

/// At least one page has been successfully fetched.
///
/// - [events]               — accumulated event list across all fetched pages.
/// - [nextCursor]           — opaque cursor for the next page; null = end of
///                            stream, [loadMore()] is a no-op.
/// - [isLoadingMore]        — true while the next-page request is in flight.
///                            D3 uses this to render a footer spinner without
///                            reverting to [DiscoverLoading].
/// - [distanceFilterDropped] — true when the distance filter was active but
///                            location was unavailable (permission denied /
///                            timeout). D3 renders a soft banner. The filter
///                            state in D1 is NOT mutated; this is fetch-scoped.
/// - [paginationError]      — non-null when [loadMore()] failed; carries the
///                            [Failure] from the last failed pagination request.
///                            D3 renders this as an inline error footer with a
///                            retry callback. Cleared on the next successful
///                            [loadMore()] or on a full [refresh()].
class DiscoverLoaded extends DiscoverState {
  const DiscoverLoaded({
    required this.events,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.distanceFilterDropped = false,
    this.paginationError,
  });

  final List<Event> events;
  final String? nextCursor;
  final bool isLoadingMore;
  final bool distanceFilterDropped;
  final Failure? paginationError;

  /// Convenience: whether more pages are available.
  bool get hasMore => nextCursor != null;

  DiscoverLoaded copyWith({
    List<Event>? events,
    Object? nextCursor = _sentinel,
    bool? isLoadingMore,
    bool? distanceFilterDropped,
    Object? paginationError = _sentinel,
  }) {
    return DiscoverLoaded(
      events: events ?? this.events,
      nextCursor: nextCursor == _sentinel
          ? this.nextCursor
          : nextCursor as String?,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      distanceFilterDropped:
          distanceFilterDropped ?? this.distanceFilterDropped,
      paginationError: paginationError == _sentinel
          ? this.paginationError
          : paginationError as Failure?,
    );
  }

  @override
  List<Object?> get props => [
    events,
    nextCursor,
    isLoadingMore,
    distanceFilterDropped,
    paginationError,
  ];
}

/// The fetch succeeded but zero events were returned.
///
/// [reason] distinguishes the two designer §G empty-state flavors so the view
/// can render the correct copy without re-evaluating filter state.
class DiscoverEmpty extends DiscoverState {
  const DiscoverEmpty(this.reason);

  final DiscoverEmptyReason reason;

  @override
  List<Object?> get props => [reason];
}

/// The use case returned a [Failure]. D3 reads [failure] to select the right
/// error-state copy (network vs server vs unknown).
class DiscoverError extends DiscoverState {
  const DiscoverError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

// Sentinel for copyWith nullable-field overrides.
const Object _sentinel = Object();
