import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/pending_check_in.dart';

/// State machine for the foreground check-in flow.
///
/// Transitions driven by [CheckInsController]:
///   Idle → Loading (on refresh())
///   Loading → Showing(item) (on non-empty surface result)
///   Loading → Empty           (on empty surface result)
///   Loading → Error(failure)  (on surface failure)
///   Showing → Loading         (on acknowledged() / flagged() → re-surface)
///   Showing → Idle            (on dismissShown())
///
/// [CheckInsLoading] is the only intermediate state.
/// Transitions land directly on a terminal state ([CheckInsShowing], [CheckInsEmpty], [CheckInsError]).
///
/// NOTE: `SafetyReportPage._onSend()` synchronously reads controller state after
/// awaiting `flagged()` to decide navigation. If an intermediate submit-progress
/// state is added between `CheckInsLoading` and a terminal state, that call site
/// must be migrated to `ref.listen`-based nav.
sealed class CheckInsState extends Equatable {
  const CheckInsState();
}

/// No active check-in is being shown. This is the initial state and the state
/// after the user dismisses a shown check-in without acting on it.
final class CheckInsIdle extends CheckInsState {
  const CheckInsIdle();

  @override
  List<Object?> get props => [];
}

/// A surface-pending call is in flight.
final class CheckInsLoading extends CheckInsState {
  const CheckInsLoading();

  @override
  List<Object?> get props => [];
}

/// A pending check-in is ready to be shown to the user.
final class CheckInsShowing extends CheckInsState {
  const CheckInsShowing({required this.item});

  final PendingCheckIn item;

  @override
  List<Object?> get props => [item];
}

/// The surface call returned an empty list — no pending check-ins.
final class CheckInsEmpty extends CheckInsState {
  const CheckInsEmpty();

  @override
  List<Object?> get props => [];
}

/// The surface call (or a subsequent acknowledge/flag) failed.
final class CheckInsError extends CheckInsState {
  const CheckInsError({required this.failure});

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
