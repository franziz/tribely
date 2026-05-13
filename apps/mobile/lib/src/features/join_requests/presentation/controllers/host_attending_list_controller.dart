import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/list_approved_for_event_usecase.dart';
import '../providers/join_requests_providers.dart';
import '../state/host_attending_list_state.dart';

/// Owns the host's per-event attending (approved) join-requests list.
///
/// Keyed by eventId via [NotifierProvider.autoDispose.family]. Kicks off a
/// fetch on build so the page never starts at Initial.
///
/// This controller is intentionally simpler than [HostPendingListController]:
/// it has no inline actions (Attending rows are read-only). The only
/// state transitions are Loading → Loaded and Loading → Error, plus a
/// refresh triggered by [HostPendingListController.approve] via
/// [ref.invalidate(hostAttendingListControllerProvider(eventId))].
class HostAttendingListController extends Notifier<HostAttendingListState> {
  HostAttendingListController(this.eventId);

  final String eventId;

  @override
  HostAttendingListState build() {
    Future(() => _load());
    return const HostAttendingListLoading();
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    state = const HostAttendingListLoading();

    final useCase = ref.read(listApprovedForEventUseCaseProvider);
    final params = ListApprovedForEventParams(eventId: eventId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) => HostAttendingListError(failure: failure),
      (items) => HostAttendingListLoaded(items: items),
    );
  }

  /// Public retry after a full fetch error.
  Future<void> retry() => _load();
}
