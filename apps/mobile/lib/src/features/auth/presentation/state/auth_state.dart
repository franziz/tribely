import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/auth_session.dart';

/// SessionState — what `SessionController` exposes.
sealed class SessionState extends Equatable {
  const SessionState();
  @override
  List<Object?> get props => [];
}

/// App is booting; we haven't determined whether the user is signed in.
/// The splash screen renders while we're in this state.
class SessionRestoring extends SessionState {
  const SessionRestoring();
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated({this.reason});
  final String? reason; // optional banner copy on /welcome
  @override
  List<Object?> get props => [reason];
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.session);
  final AuthSession session;
  @override
  List<Object?> get props => [session];
}

/// AuthFormState — what `SignInController` and `SignUpController` expose.
/// Drives the form's button state, banners, validation copy.
sealed class AuthFormState extends Equatable {
  const AuthFormState();
  @override
  List<Object?> get props => [];
}

class AuthFormIdle extends AuthFormState {
  const AuthFormIdle();
}

class AuthFormSubmitting extends AuthFormState {
  const AuthFormSubmitting();
}

class AuthFormSuccess extends AuthFormState {
  const AuthFormSuccess();
}

/// Form-level error (banner copy + optional rate-limit countdown + optional
/// pre-fill hint for the email-already-exists 409 case).
class AuthFormError extends AuthFormState {
  const AuthFormError({
    required this.failure,
    this.bannerMessage,
    this.retryAfterSeconds,
    this.suggestSignInWithEmail,
  });

  final Failure failure;
  final String? bannerMessage;
  final int? retryAfterSeconds;
  final String? suggestSignInWithEmail;

  @override
  List<Object?> get props => [
    failure,
    bannerMessage,
    retryAfterSeconds,
    suggestSignInWithEmail,
  ];
}

/// VerifyEmailState — drives the verify-email page (code field, submit
/// button, resend button + cooldown).
sealed class VerifyEmailState extends Equatable {
  const VerifyEmailState({this.resendCooldownSeconds = 0});
  final int resendCooldownSeconds;

  @override
  List<Object?> get props => [resendCooldownSeconds];
}

class VerifyEmailIdle extends VerifyEmailState {
  const VerifyEmailIdle({super.resendCooldownSeconds = 0});
}

class VerifyEmailSubmitting extends VerifyEmailState {
  const VerifyEmailSubmitting({super.resendCooldownSeconds = 0});
}

class VerifyEmailResending extends VerifyEmailState {
  const VerifyEmailResending({super.resendCooldownSeconds = 0});
}

class VerifyEmailSuccess extends VerifyEmailState {
  const VerifyEmailSuccess();
}

class VerifyEmailError extends VerifyEmailState {
  const VerifyEmailError({
    required this.failure,
    required this.bannerMessage,
    super.resendCooldownSeconds = 0,
  });

  final Failure failure;
  final String bannerMessage;

  @override
  List<Object?> get props => [...super.props, failure, bannerMessage];
}

class VerifyEmailResendSent extends VerifyEmailState {
  const VerifyEmailResendSent({super.resendCooldownSeconds = 60});
}
