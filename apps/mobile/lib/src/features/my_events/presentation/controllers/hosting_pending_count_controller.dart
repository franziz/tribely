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
/// Failures are swallowed per-event (count stays 0 for failed IDs) so a
/// transient error on one event doesn't break the whole badge.
class HostingPendingCountState {
  const HostingPendingCountState({
    required this.total,
    required this.perEvent,
    this.isLoading = false,
  });

  /// Total pending requests across all hosted events. Drives notification dot.
  final int total;

  /// Per-event pending counts. Keys are event IDs; missing key → 0 pending.
  final Map<String, int> perEvent;

  /// True during the initial load or a refresh.
  final bool isLoading;
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

    // Fire all requests in parallel; swallow individual failures gracefully.
    final results = await Future.wait(
      eventIds.map((id) async {
        final result = await useCase(ListPendingForEventParams(eventId: id));
        return MapEntry(id, result.fold((_) => 0, (items) => items.length));
      }),
    );

    if (!ref.mounted) return;

    final perEvent = Map<String, int>.fromEntries(results);
    final total = perEvent.values.fold(0, (sum, count) => sum + count);

    state = HostingPendingCountState(
      total: total,
      perEvent: perEvent,
      isLoading: false,
    );
  }

  /// Refresh all counts — called on tab focus via Riverpod invalidate().
  Future<void> refresh() => _load();
}
