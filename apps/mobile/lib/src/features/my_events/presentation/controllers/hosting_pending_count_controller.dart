import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../join_requests/domain/usecases/list_pending_for_event_usecase.dart';
import '../../../join_requests/presentation/providers/join_requests_providers.dart';

/// Aggregate pending-request count across a set of hosted events.
///
/// Keyed by the list of hosted event IDs via
/// [NotifierProvider.autoDispose.family]. On build, fires parallel
/// [ListPendingForEventUseCase] calls and aggregates results into:
///   - [HostingPendingCountState.total]: total count (drives notification dot)
///   - [HostingPendingCountState.perEvent]: per-event counts (drives row captions)
///
/// Strategy: naive `Future.wait` — correct at MVP scale (single-digit hosted
/// events per user). Revisit when host event lists grow large.
///
/// Per-event failures are captured in [HostingPendingCountState.failedEventIds].
/// A single bounded auto-retry fires 5 s after initial load if any ids failed;
/// if the retry also fails those ids persist in [failedEventIds] until the next
/// user-driven refresh (pull-to-refresh / tab re-tap).
class HostingPendingCountState extends Equatable {
  const HostingPendingCountState({
    required this.total,
    required this.perEvent,
    this.isLoading = false,
    this.failedEventIds = const <String>{},
  });

  /// Total pending requests across all hosted events. Drives notification dot.
  final int total;

  /// Per-event pending counts. Keys are event IDs; missing key → 0 pending.
  final Map<String, int> perEvent;

  /// True during the initial load or a refresh.
  final bool isLoading;

  /// Event IDs for which the most recent fetch failed.
  ///
  /// These IDs are counted as 0 for [total] and [perEvent]; the badge may
  /// under-report until a retry or user-driven refresh clears the set.
  final Set<String> failedEventIds;

  @override
  List<Object?> get props => [total, perEvent, isLoading, failedEventIds];
}

/// Provider — autoDispose + family keyed by the list of hosted event IDs.
final hostingPendingCountControllerProvider = NotifierProvider.autoDispose
    .family<
      HostingPendingCountController,
      HostingPendingCountState,
      List<String>
    >(HostingPendingCountController.new);

class HostingPendingCountController extends Notifier<HostingPendingCountState> {
  HostingPendingCountController(this.eventIds);

  final List<String> eventIds;

  @override
  HostingPendingCountState build() {
    Future(() => _load());
    return const HostingPendingCountState(
      total: 0,
      perEvent: {},
      isLoading: true,
    );
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    state = HostingPendingCountState(
      total: state.total,
      perEvent: state.perEvent,
      isLoading: true,
    );

    final useCase = ref.read(listPendingForEventUseCaseProvider);

    // Fire all requests in parallel; capture per-event failures.
    final results = await Future.wait(
      eventIds.map((id) async {
        final result = await useCase(ListPendingForEventParams(eventId: id));
        // Returns (id, count) on success, (id, null) on failure.
        return MapEntry(id, result.fold((_) => null, (items) => items.length));
      }),
    );

    if (!ref.mounted) return;

    final perEvent = <String, int>{};
    final failedIds = <String>{};

    for (final entry in results) {
      if (entry.value != null) {
        perEvent[entry.key] = entry.value!;
      } else {
        perEvent[entry.key] = 0;
        failedIds.add(entry.key);
      }
    }

    final total = perEvent.values.fold(0, (sum, count) => sum + count);

    state = HostingPendingCountState(
      total: total,
      perEvent: perEvent,
      isLoading: false,
      failedEventIds: failedIds,
    );

    // Schedule one bounded auto-retry for failed IDs. If the retry also fails,
    // the ids persist in failedEventIds until the next user-driven refresh.
    if (failedIds.isNotEmpty) {
      Future.delayed(const Duration(seconds: 5), () => _retryFailed(failedIds));
    }
  }

  /// Retry fetching counts for [ids] that failed during the previous load.
  ///
  /// Merges successes into the current state; leaves persistent failures in
  /// [failedEventIds]. Does NOT schedule a further retry — one attempt only.
  Future<void> _retryFailed(Set<String> ids) async {
    if (!ref.mounted) return;

    // Concurrency safety: if a user-driven refresh already re-fetched these
    // ids (i.e. they're no longer in failedEventIds), skip the retry.
    final stillFailed = ids.intersection(state.failedEventIds);
    if (stillFailed.isEmpty) return;

    final useCase = ref.read(listPendingForEventUseCaseProvider);

    final results = await Future.wait(
      stillFailed.map((id) async {
        final result = await useCase(ListPendingForEventParams(eventId: id));
        return MapEntry(id, result.fold((_) => null, (items) => items.length));
      }),
    );

    if (!ref.mounted) return;

    final updatedPerEvent = Map<String, int>.from(state.perEvent);
    final updatedFailedIds = Set<String>.from(state.failedEventIds);

    for (final entry in results) {
      if (entry.value != null) {
        updatedPerEvent[entry.key] = entry.value!;
        updatedFailedIds.remove(entry.key);
      }
      // Continued failures: keep id in failedEventIds; no further retry.
    }

    final newTotal = updatedPerEvent.values.fold(
      0,
      (sum, count) => sum + count,
    );

    state = HostingPendingCountState(
      total: newTotal,
      perEvent: updatedPerEvent,
      isLoading: false,
      failedEventIds: updatedFailedIds,
    );
  }

  /// Refresh all counts — called on tab focus via Riverpod invalidate().
  Future<void> refresh() => _load();
}
