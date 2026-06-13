import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';

/// Drives the [SignInGateSheet] widget.
///
/// Transition diagram:
///   idle → submitting → success
///                     ↘ error (sheet stays open; user may retry)
sealed class SignInGateState extends Equatable {
  const SignInGateState();
  @override
  List<Object?> get props => [];
}

class SignInGateIdle extends SignInGateState {
  const SignInGateIdle();
}

class SignInGateSubmitting extends SignInGateState {
  const SignInGateSubmitting();
}

/// Auth-error in-place — sheet stays open, banner is rendered above the fields.
class SignInGateError extends SignInGateState {
  const SignInGateError({required this.failure, required this.message});
  final Failure failure;
  final String message;

  @override
  List<Object?> get props => [failure, message];
}

/// Auth succeeded. The [SignInGateSheet] pops with `true`; the CALLER (Briefs
/// B/C) reads the result and resumes the intended action.
class SignInGateSuccess extends SignInGateState {
  const SignInGateSuccess();
}
