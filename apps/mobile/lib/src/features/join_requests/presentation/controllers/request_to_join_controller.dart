import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/join_request.dart';
import '../../domain/usecases/request_to_join_event_usecase.dart';
import '../providers/join_requests_providers.dart';
import '../state/request_to_join_state.dart';

/// Owns the per-event "Request to Join" CTA state.
///
/// Keyed by eventId via [NotifierProvider.autoDispose.family] — each event
/// gets its own isolated controller instance that is discarded when the
/// consuming widget leaves the tree.
///
/// Responsibilities:
///   - Submit a join request and transition Idle → Submitting → Submitted | Failed
///   - Allow the page to seed an existing request on init ([initialize])
///   - Reset to Idle after an error or after the user withdraws a request
class RequestToJoinController extends Notifier<RequestToJoinState> {
  RequestToJoinController(this.eventId);

  final String eventId;

  @override
  RequestToJoinState build() => const RequestToJoinIdle();

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

  /// Returns to [RequestToJoinIdle]. Call after the UI acknowledges an error
  /// or after the user's withdrawal has been processed.
  void reset({JoinRequest? existingRequest}) {
    state = RequestToJoinIdle(existingRequest: existingRequest);
  }
}
