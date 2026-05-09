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
  List<Object?> get props =>
      [failure, bannerMessage, retryAfterSeconds, suggestSignInWithEmail];
}
