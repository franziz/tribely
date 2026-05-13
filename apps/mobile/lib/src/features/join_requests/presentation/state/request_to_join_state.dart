import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/join_request.dart';

/// State machine for the per-event "Request to Join" CTA.
///
/// Transitions:
///   Idle ──────────── submit() ──────────► Submitting
///   Submitting ─────── success ──────────► Submitted(joinRequest)
///   Submitting ─────── failure ──────────► Failed(failure)
///   Idle(pending) ─── withdraw() ────────► Withdrawing
///   Withdrawing ────── success ──────────► Idle(existingRequest: withdrawn)
///   Withdrawing ────── failure ──────────► Failed(failure)
///   Failed / Submitted ── reset() ───────► Idle
sealed class RequestToJoinState extends Equatable {
  const RequestToJoinState();
}

/// Default state. Carries an existing [JoinRequest] when the user already has
/// one for this event (e.g. after a page reload), so the UI can render the
/// current status without needing a separate fetch.
final class RequestToJoinIdle extends RequestToJoinState {
  const RequestToJoinIdle({this.existingRequest});

  /// Non-null when the user already has a join request for this event.
  final JoinRequest? existingRequest;

  @override
  List<Object?> get props => [existingRequest];
}

/// A request submission is in flight.
final class RequestToJoinSubmitting extends RequestToJoinState {
  const RequestToJoinSubmitting();

  @override
  List<Object?> get props => [];
}

/// Submission succeeded. [joinRequest] is the server-confirmed entity.
final class RequestToJoinSubmitted extends RequestToJoinState {
  const RequestToJoinSubmitted({required this.joinRequest});

  final JoinRequest joinRequest;

  @override
  List<Object?> get props => [joinRequest];
}

/// Submission failed. [failure] carries the typed domain failure so the UI
/// can render context-specific copy (capacity full, email unverified, etc.).
final class RequestToJoinFailed extends RequestToJoinState {
  const RequestToJoinFailed({required this.failure});

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// A withdraw operation is in flight. [withdrawingRequest] is the pending
/// request being withdrawn — kept to avoid a flicker in the pill display.
final class RequestToJoinWithdrawing extends RequestToJoinState {
  const RequestToJoinWithdrawing({this.withdrawingRequest});

  final JoinRequest? withdrawingRequest;

  @override
  List<Object?> get props => [withdrawingRequest];
}
