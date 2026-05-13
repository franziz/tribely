import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/join_request_with_requester.dart';
import '../../domain/usecases/approve_join_request_usecase.dart';
import '../../domain/usecases/decline_join_request_usecase.dart';
import '../../domain/usecases/list_pending_for_event_usecase.dart';
import '../providers/join_requests_providers.dart';
import '../state/host_pending_list_state.dart';

/// Owns the host's per-event pending join-requests list.
///
/// Keyed by eventId via [NotifierProvider.autoDispose.family]. Kicks off a
/// fetch on build so the page never starts at Initial.
///
/// Responsibilities:
///   - Fetch pending requests for [eventId] on build
///   - Expose [approve] and [decline] actions that optimistically remove the
///     acted-upon item from the list and surface failures without a full reload
class HostPendingListController extends Notifier<HostPendingListState> {
  HostPendingListController(this.eventId);

  final String eventId;

  @override
  HostPendingListState build() {
    Future(() => _load());
    return const HostPendingListLoading();
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    state = const HostPendingListLoading();

    final useCase = ref.read(listPendingForEventUseCaseProvider);
    final params = ListPendingForEventParams(eventId: eventId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) => HostPendingListError(failure: failure),
      (items) => HostPendingListLoaded(items: items),
    );
  }

  /// Retry after a transient error.
  Future<void> retry() => _load();

  /// Approve [joinRequestId]. On success the entry is removed from the list;
  /// on failure the list is unchanged and the error is surfaced via state.
  Future<void> approve(String joinRequestId) async {
    final useCase = ref.read(approveJoinRequestUseCaseProvider);
    final params = ApproveJoinRequestParams(joinRequestId: joinRequestId);
    final result = await useCase(params);
    if (!ref.mounted) return;
    result.fold(
      (failure) => state = HostPendingListError(failure: failure),
      (_) => _removeFromList(joinRequestId),
    );
  }

  /// Decline [joinRequestId]. On success the entry is removed from the list;
  /// on failure the list is unchanged and the error is surfaced via state.
  Future<void> decline(String joinRequestId, {String? reason}) async {
    final useCase = ref.read(declineJoinRequestUseCaseProvider);
    final params = DeclineJoinRequestParams(
      joinRequestId: joinRequestId,
      reason: reason,
    );
    final result = await useCase(params);
    if (!ref.mounted) return;
    result.fold(
      (failure) => state = HostPendingListError(failure: failure),
      (_) => _removeFromList(joinRequestId),
    );
  }

  void _removeFromList(String joinRequestId) {
    final current = state;
    if (current is! HostPendingListLoaded) return;
    final updated = current.items
        .where((item) => item.joinRequest.id != joinRequestId)
        .toList(growable: false);
    state = HostPendingListLoaded(items: updated);
  }

  /// Returns the current pending list, or an empty list if not yet loaded.
  List<JoinRequestWithRequester> get items => switch (state) {
    HostPendingListLoaded(:final items) => items,
    _ => const [],
  };
}
