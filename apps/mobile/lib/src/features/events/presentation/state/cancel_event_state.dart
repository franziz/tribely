import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';

/// State machine for the per-event "Cancel Event" action.
///
/// Transitions:
///   Idle ─────────── cancel() ──────────► Submitting
///   Submitting ────── success ──────────► Success
///   Submitting ────── failure ──────────► Failed(failure)
sealed class CancelEventState extends Equatable {
  const CancelEventState();
}

/// Default state. The cancel action has not been initiated.
final class CancelEventIdle extends CancelEventState {
  const CancelEventIdle();

  @override
  List<Object?> get props => [];
}

/// A cancel request is in flight. The UI should disable the action and show
/// a loading indicator.
final class CancelEventSubmitting extends CancelEventState {
  const CancelEventSubmitting();

  @override
  List<Object?> get props => [];
}

/// The cancel request succeeded. The UI should update the event display and
/// navigate away (navigation is owned by the page, not this controller).
final class CancelEventSuccess extends CancelEventState {
  const CancelEventSuccess();

  @override
  List<Object?> get props => [];
}

/// The cancel request failed. [failure] carries the typed domain failure so
/// the UI can render context-specific copy (already cancelled, network error,
/// etc.).
final class CancelEventFailed extends CancelEventState {
  const CancelEventFailed({required this.failure});

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
