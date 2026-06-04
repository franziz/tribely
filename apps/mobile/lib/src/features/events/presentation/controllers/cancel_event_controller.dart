import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/events_providers.dart';
import '../state/cancel_event_state.dart';
import '../../domain/usecases/cancel_event_usecase.dart';

/// Owns the per-event cancel-event action state.
///
/// Keyed by eventId via [NotifierProvider.autoDispose.family] — each event
/// gets its own isolated controller instance that is discarded when the
/// consuming widget leaves the tree.
///
/// Responsibilities:
///   - Submit a cancel request: Idle → Submitting → Success | Failed
///   - Carry the typed [Failure] to the UI on error (including already-cancelled,
///     network, and any 403 defensive case)
///
/// Navigation is NOT performed here. On [CancelEventSuccess] the page
/// observes the state and performs the appropriate transition.
/// Provider invalidation is NOT done here — Brief D wires that on the page.
class CancelEventController extends Notifier<CancelEventState> {
  CancelEventController(this.eventId);

  final String eventId;

  @override
  CancelEventState build() => const CancelEventIdle();

  /// Submits the cancel request for [eventId].
  ///
  /// Guards against re-entry: if a submission is already in flight the call
  /// is a no-op.
  Future<void> cancel() async {
    if (state is CancelEventSubmitting) return;
    state = const CancelEventSubmitting();

    if (!ref.mounted) return;
    final useCase = ref.read(cancelEventUseCaseProvider);
    final params = CancelEventParams(eventId: eventId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) => CancelEventFailed(failure: failure),
      (_) => const CancelEventSuccess(),
    );
  }
}

/// Provider keyed by eventId.
///
/// Each event detail page that renders a cancel button gets its own isolated
/// state. autoDispose discards the state when the page is popped.
final cancelEventControllerProvider = NotifierProvider.autoDispose
    .family<CancelEventController, CancelEventState, String>(
      CancelEventController.new,
    );
