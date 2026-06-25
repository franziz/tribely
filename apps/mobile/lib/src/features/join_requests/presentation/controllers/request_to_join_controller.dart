import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
// Sanctioned cross-feature import (exception-1): session identity is app-global
// state. Required here to short-circuit the GET /me/join-requests call when
// the viewer is unauthenticated (TRI-290).
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../../users/presentation/providers/capability_providers.dart';
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
  ///
  /// Short-circuits to [RequestToJoinIdle] (no existing request) when the
  /// viewer is unauthenticated — avoids a doomed GET /me/join-requests 401
  /// on the TRI-290 anonymous event-detail view. The terminal state is
  /// identical to what [_classifyLoadFailure] already produces for
  /// [AuthFailure], so the UI sees no difference.
  Future<void> loadExisting() async {
    if (!ref.mounted) return;

    // TRI-290: skip the network call entirely when signed out.
    final session = ref.read(sessionControllerProvider);
    if (session is SessionUnauthenticated) {
      state = const RequestToJoinIdle(existingRequest: null);
      return;
    }

    final useCase = ref.read(listMyJoinRequestsUseCaseProvider);
    final params = ListMyJoinRequestsParams(eventId: eventId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    result.fold(
      (failure) {
        state = _classifyLoadFailure(failure);
      },
      (items) {
        final existing = items.isNotEmpty ? items.first.joinRequest : null;
        state = RequestToJoinIdle(existingRequest: existing);
      },
    );
  }

  /// Classifies a [Failure] from [loadExisting] into the appropriate state.
  ///
  /// An [AuthFailure] means the viewer is unauthenticated — they have no
  /// existing request, so we stay at [RequestToJoinIdle] with no request.
  /// All other failures (network, 5xx, timeout, etc.) are surfaced as
  /// [RequestToJoinFailed] so the UI can react rather than silently staying
  /// Idle with stale or missing data.
  RequestToJoinState _classifyLoadFailure(Failure failure) {
    if (failure is AuthFailure) {
      // Unauthenticated → definitively no existing request. Explicit Idle,
      // not a bare null no-op.
      return const RequestToJoinIdle(existingRequest: null);
    }
    // Network, 5xx, timeout, or any other unexpected failure — surface it.
    return RequestToJoinFailed(failure: failure);
  }

  /// Seed an already-known [JoinRequest] into the Idle state (e.g. when the
  /// page receives the current join-request status from a prior fetch).
  void initialize(JoinRequest? existingRequest) {
    state = RequestToJoinIdle(existingRequest: existingRequest);
  }

  /// Submits a join request for [eventId].
  ///
  /// [acknowledgedSafetyReminder] — pass `true` when the user has tapped
  /// through the safety reminder sheet (TRI-34 Brief G). The flag is forwarded
  /// to the POST body as `acknowledgedSafetyReminder`.
  ///
  /// On success with [acknowledgedSafetyReminder] == true, locally flips the
  /// [myCapabilitiesProvider] cache so [safetyReminderSeen] becomes `true`
  /// without a network re-fetch.
  Future<void> submit({bool acknowledgedSafetyReminder = false}) async {
    if (state is RequestToJoinSubmitting) return;
    state = const RequestToJoinSubmitting();

    final useCase = ref.read(requestToJoinEventUseCaseProvider);
    final params = RequestToJoinEventParams(
      eventId: eventId,
      acknowledgedSafetyReminder: acknowledgedSafetyReminder,
    );
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold((failure) => RequestToJoinFailed(failure: failure), (
      joinRequest,
    ) {
      // Local cache flip: when the safety reminder was acknowledged, update
      // the cached capabilities so subsequent joins go straight to
      // ConfirmJoinSheet without a network round-trip. No ref.invalidate —
      // that would trigger a redundant fetch on the hot path.
      if (acknowledgedSafetyReminder) {
        _flipSafetyReminderSeen();
      }
      return RequestToJoinSubmitted(joinRequest: joinRequest);
    });
  }

  /// Locally flips the [myCapabilitiesProvider] cache so `safetyReminderSeen`
  /// becomes `true` without a network re-fetch.
  ///
  /// Delegates to [MyCapabilitiesNotifier.markSafetyReminderSeen] which does a
  /// no-op when the value is already true or the provider is not yet loaded.
  void _flipSafetyReminderSeen() {
    ref.read(myCapabilitiesProvider.notifier).markSafetyReminderSeen();
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
