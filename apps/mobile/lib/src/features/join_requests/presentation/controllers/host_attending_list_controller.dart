import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/join_request_with_requester.dart';
import '../../domain/usecases/list_approved_for_event_usecase.dart';
import '../../domain/usecases/remove_attendee_usecase.dart';
import '../providers/join_requests_providers.dart';
import '../state/host_attending_list_state.dart';

/// Owns the host's per-event attending (approved) join-requests list.
///
/// Keyed by eventId via [NotifierProvider.autoDispose.family]. Kicks off a
/// fetch on build so the page never starts at Initial.
///
/// State transitions:
///   - Loading → (Loaded | Error) on initial fetch.
///   - Refresh triggered by [HostPendingListController.approve] via
///     [ref.invalidate(hostAttendingListControllerProvider(eventId))].
///   - [removeAttendee] performs an optimistic remove: the row is removed from
///     the rendered list immediately; on failure it is restored and a human-
///     readable error string is returned to the sheet.
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

  /// Remove an approved attendee from the event.
  ///
  /// - Snapshots current state.
  /// - Optimistically removes [item] from the rendered list.
  /// - Calls [RemoveAttendeeUseCase].
  /// - On [Either.Left]: restores snapshot; returns a human-readable error
  ///   string (sheet displays inline [BannerMessage], reason text preserved).
  /// - On [Either.Right]: returns null (success → sheet auto-pops).
  ///
  /// Matches [DeclineReasonSheet.onSubmit] contract: null=success, string=error.
  Future<String?> removeAttendee({
    required JoinRequestWithRequester item,
    required String eventTitle,
    required String reason,
  }) async {
    final snapshot = state;

    // Optimistic remove.
    if (snapshot is HostAttendingListLoaded) {
      final updated = snapshot.items
          .where((i) => i.joinRequest.id != item.joinRequest.id)
          .toList(growable: false);
      state = snapshot.copyWith(items: updated);
    }

    final useCase = ref.read(removeAttendeeUseCaseProvider);
    final params = RemoveAttendeeParams(
      eventId: eventId,
      joinRequestId: item.joinRequest.id,
      reason: reason,
    );
    final result = await useCase(params);

    if (!ref.mounted) return null;

    return result.fold(
      (failure) {
        // Rollback on failure.
        state = snapshot;
        return failure.message;
      },
      (_) => null, // success
    );
  }
}
