import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/join_request.dart';
import '../../domain/usecases/list_my_join_requests_usecase.dart';
import '../../domain/usecases/request_to_join_event_usecase.dart';
import '../../domain/usecases/withdraw_join_request_usecase.dart';
import '../providers/join_requests_providers.dart';
import '../state/request_to_join_state.dart';

/// Owns the per-event "Request to Join" CTA state.
///
/// Keyed by eventId via [NotifierProvider.autoDispose.family] — each event
/// gets its own isolated controller instance that is discarded when the
/// consuming widget leaves the tree.
///
/// Responsibilities:
///   - Load any existing join request for the viewer on this event ([loadExisting])
///   - Submit a join request and transition Idle → Submitting → Submitted | Failed
///   - Withdraw an existing pending request ([withdraw])
///   - Allow the page to seed an existing request on init ([initialize])
///   - Reset to Idle after an error ([reset])
class RequestToJoinController extends Notifier<RequestToJoinState> {
  RequestToJoinController(this.eventId);

  final String eventId;

  @override
  RequestToJoinState build() {
    // Kick off an existing-request lookup on construction so the sticky bar
    // renders the correct initial state without requiring a separate call.
    Future(() => loadExisting());
    return const RequestToJoinIdle();
  }

  /// Fetches the viewer's existing join request for [eventId] (if any).
  ///
  /// Called automatically on [build]. Page code can call this again after a
  /// state transition to re-sync with the server.
  Future<void> loadExisting() async {
    if (!ref.mounted) return;

    final useCase = ref.read(listMyJoinRequestsUseCaseProvider);
    final params = ListMyJoinRequestsParams(eventId: eventId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    result.fold(
      // On failure (e.g. 401 unauthenticated) stay at Idle with no request —
      // the user is not signed in so they have no existing request.
      (_) => null,
      (items) {
        final existing = items.isNotEmpty ? items.first.joinRequest : null;
        state = RequestToJoinIdle(existingRequest: existing);
      },
    );
  }

  /// Seed an already-known [JoinRequest] into the Idle state (e.g. when the
  /// page receives the current join-request status from a prior fetch).
  void initialize(JoinRequest? existingRequest) {
    state = RequestToJoinIdle(existingRequest: existingRequest);
  }

  /// Submits a join request for [eventId].
  Future<void> submit() async {
    if (state is RequestToJoinSubmitting) return;
    state = const RequestToJoinSubmitting();

    final useCase = ref.read(requestToJoinEventUseCaseProvider);
    final params = RequestToJoinEventParams(eventId: eventId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) => RequestToJoinFailed(failure: failure),
      (joinRequest) => RequestToJoinSubmitted(joinRequest: joinRequest),
    );
  }

  /// Withdraws the pending join request identified by [joinRequestId].
  ///
  /// Transitions: Idle(pending) → Withdrawing → Idle(withdrawn) | Failed.
  Future<void> withdraw(String joinRequestId) async {
    if (state is RequestToJoinWithdrawing) return;

    // Carry the current existing request into withdrawing so the pill stays
    // visible while the network call is in flight.
    final current = state;
    final existing = current is RequestToJoinIdle
        ? current.existingRequest
        : null;
    state = RequestToJoinWithdrawing(withdrawingRequest: existing);

    final useCase = ref.read(withdrawJoinRequestUseCaseProvider);
    final params = WithdrawJoinRequestParams(joinRequestId: joinRequestId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    result.fold(
      (failure) {
        // Revert to idle with the original request on failure.
        state = RequestToJoinFailed(failure: failure);
      },
      (_) {
        // Update the existing request's status to withdrawn locally.
        final withdrawn = existing?.copyWith(
          status: JoinRequestStatus.withdrawn,
        );
        state = RequestToJoinIdle(existingRequest: withdrawn);
      },
    );
  }

  /// Returns to [RequestToJoinIdle]. Call after the UI acknowledges an error.
  void reset({JoinRequest? existingRequest}) {
    state = RequestToJoinIdle(existingRequest: existingRequest);
  }
}
