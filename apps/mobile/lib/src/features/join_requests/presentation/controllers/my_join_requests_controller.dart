import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/join_request.dart';
import '../../domain/entities/join_request_with_event.dart';
import '../../domain/usecases/list_my_join_requests_usecase.dart';
import '../../domain/usecases/withdraw_join_request_usecase.dart';
import '../providers/join_requests_providers.dart';
import '../state/my_join_requests_state.dart';

/// Owns the joiner's "My Requests" tab state.
///
/// Optionally keyed by eventId (for when the tab is scoped to a single event).
/// When [eventId] is null, fetches all of the current user's join requests.
///
/// Kicks off a fetch on build so the page never starts at Initial.
///
/// Responsibilities:
///   - Load join requests on build and expose [retry] / [refresh]
///   - [withdraw]: soft-delete a pending request, update the row's status to
///     withdrawn in-place (row stays in the list per spec)
class MyJoinRequestsController extends Notifier<MyJoinRequestsState> {
  MyJoinRequestsController(this.eventId);

  /// Optional event filter. Null means "all my requests".
  final String? eventId;

  @override
  MyJoinRequestsState build() {
    Future(() => _load());
    return const MyJoinRequestsLoading();
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    state = const MyJoinRequestsLoading();

    final useCase = ref.read(listMyJoinRequestsUseCaseProvider);
    final params = ListMyJoinRequestsParams(eventId: eventId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) => MyJoinRequestsError(failure: failure),
      (items) => MyJoinRequestsLoaded(items: items),
    );
  }

  /// Retry after a transient error.
  Future<void> retry() => _load();

  /// Refresh the list (e.g. pull-to-refresh).
  Future<void> refresh() => _load();

  /// Withdraw the pending request identified by [joinRequestId].
  ///
  /// On success: the row's status transitions to [JoinRequestStatus.withdrawn]
  /// in-place (the row remains visible per spec — users can see the history).
  /// On failure: [MyJoinRequestsError] is set; the list is unchanged.
  Future<void> withdraw(String joinRequestId) async {
    final useCase = ref.read(withdrawJoinRequestUseCaseProvider);
    final params = WithdrawJoinRequestParams(joinRequestId: joinRequestId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    result.fold(
      (failure) => state = MyJoinRequestsError(failure: failure),
      (_) => _markWithdrawn(joinRequestId),
    );
  }

  /// Updates the in-place row status to [JoinRequestStatus.withdrawn] without
  /// triggering a full reload. The row stays in the list per spec.
  void _markWithdrawn(String joinRequestId) {
    final current = state;
    if (current is! MyJoinRequestsLoaded) return;
    final updated = current.items
        .map((item) {
          if (item.joinRequest.id != joinRequestId) return item;
          return JoinRequestWithEvent(
            joinRequest: item.joinRequest.copyWith(
              status: JoinRequestStatus.withdrawn,
            ),
            event: item.event,
          );
        })
        .toList(growable: false);
    state = MyJoinRequestsLoaded(items: updated);
  }
}
