import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
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
///   - Expose [approve] and [decline] actions that mark the row in-flight,
///     then either remove on success or surface an inline section error on failure
///   - 409 CapacityFull → inline section banner via [HostPendingListLoaded.sectionError];
///     row stays in the list per PM AC
///   - 409 ConflictFailure (ALREADY_APPROVED / ALREADY_REJECTED) → signal via
///     [HostPendingListLoaded.raceConflictId], then silently refetch
///   - Network errors → inline section banner + re-enable row buttons
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

  /// Public reload — called after a race-condition refetch or pull-to-refresh.
  Future<void> load() => _load();

  /// Retry after a full fetch error.
  Future<void> retry() => _load();

  /// Approve [joinRequestId].
  ///
  /// - Success: row is removed from the list with a slide-out animation.
  /// - 409 CapacityFull: inline section banner; row stays in the list.
  /// - 409 ConflictFailure (already acted): refetch silently; UI shows toast.
  /// - Network / other error: inline section banner; row buttons re-enable.
  Future<void> approve(String joinRequestId) async {
    _markInFlight(joinRequestId);

    final useCase = ref.read(approveJoinRequestUseCaseProvider);
    final params = ApproveJoinRequestParams(joinRequestId: joinRequestId);
    final result = await useCase(params);

    if (!ref.mounted) return;

    result.fold(
      (failure) => _handleActionFailure(failure, joinRequestId),
      (_) => _removeFromList(joinRequestId),
    );
  }

  /// Decline [joinRequestId] with an optional [reason].
  ///
  /// Same error-handling semantics as [approve].
  Future<void> decline(String joinRequestId, {String? reason}) async {
    _markInFlight(joinRequestId);

    final useCase = ref.read(declineJoinRequestUseCaseProvider);
    final params = DeclineJoinRequestParams(
      joinRequestId: joinRequestId,
      reason: reason,
    );
    final result = await useCase(params);

    if (!ref.mounted) return;

    result.fold(
      (failure) => _handleActionFailure(failure, joinRequestId),
      (_) => _removeFromList(joinRequestId),
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Set the in-flight ID so the row disables its buttons during the request.
  void _markInFlight(String joinRequestId) {
    final current = state;
    if (current is HostPendingListLoaded) {
      state = current.copyWith(
        actionInFlightId: joinRequestId,
        sectionError: null,
      );
    }
  }

  void _handleActionFailure(Failure failure, String joinRequestId) {
    final current = state;
    if (current is! HostPendingListLoaded) return;

    if (failure is ConflictFailure &&
        (failure.subcode == 'ALREADY_APPROVED' ||
            failure.subcode == 'ALREADY_REJECTED')) {
      // Race condition: signal via state, then silently refetch.
      state = current.copyWith(
        actionInFlightId: null,
        raceConflictId: joinRequestId,
      );
      _load();
      return;
    }

    final message = failure is CapacityFullFailure
        ? "This event is now full — you can't approve more joiners."
        : failure is NetworkFailure
        ? 'No connection. Check your network and try again.'
        : failure.message;

    state = current.copyWith(sectionError: message, actionInFlightId: null);
  }

  void _removeFromList(String joinRequestId) {
    final current = state;
    if (current is! HostPendingListLoaded) return;
    final updated = current.items
        .where((item) => item.joinRequest.id != joinRequestId)
        .toList(growable: false);
    state = current.copyWith(
      items: updated,
      actionInFlightId: null,
      sectionError: null,
    );
  }

  /// Dismiss the inline section error banner.
  void clearSectionError() {
    final current = state;
    if (current is HostPendingListLoaded) {
      state = current.copyWith(sectionError: null);
    }
  }

  /// Clear the race-conflict signal after the UI has shown its toast.
  void clearRaceConflict() {
    final current = state;
    if (current is HostPendingListLoaded && current.raceConflictId != null) {
      state = current.copyWith(raceConflictId: null);
    }
  }
}
