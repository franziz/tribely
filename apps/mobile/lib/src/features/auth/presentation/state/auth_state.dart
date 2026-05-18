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
  const SessionAuthenticated(this.session, {this.phoneRevokedSinceLastSeen = false});
  final AuthSession session;

  /// True when a session refresh / GET /me reveals that [User.phoneVerifiedAt]
  /// transitioned from non-null to null since the last time we checked.
  ///
  /// This is a fully client-derived, transient flag — it is NOT persisted and
  /// resets to false on app cold-start. The UI renders a dismissible neutral
  /// banner; [SessionController.dismissPhoneRevokedBanner] resets it.
  final bool phoneRevokedSinceLastSeen;

  @override
  List<Object?> get props => [session, phoneRevokedSinceLastSeen];
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

// ---------------------------------------------------------------------------
// PhoneVerificationState — drives the phone-OTP wizard
// (PhoneEntryPage → VerifyPhonePage)
// ---------------------------------------------------------------------------

/// Base state for the phone OTP wizard. [resendCooldownSeconds] mirrors the
/// server's rate limit with a local countdown, exactly like [VerifyEmailState].
sealed class PhoneVerificationState extends Equatable {
  const PhoneVerificationState({this.resendCooldownSeconds = 0});
  final int resendCooldownSeconds;

  @override
  List<Object?> get props => [resendCooldownSeconds];
}

class PhoneVerificationIdle extends PhoneVerificationState {
  const PhoneVerificationIdle({super.resendCooldownSeconds = 0});
}

/// Sending the start-OTP request to the server.
class PhoneVerificationSending extends PhoneVerificationState {
  const PhoneVerificationSending({super.resendCooldownSeconds = 0});
}

/// OTP sent; user is on the code-entry page.
class PhoneVerificationCodeSent extends PhoneVerificationState {
  const PhoneVerificationCodeSent({
    required this.phone,
    super.resendCooldownSeconds = 60,
  });
  final String phone;

  @override
  List<Object?> get props => [...super.props, phone];
}

/// Submitting the 6-digit code to the server.
class PhoneVerificationSubmitting extends PhoneVerificationState {
  const PhoneVerificationSubmitting({
    required this.phone,
    super.resendCooldownSeconds = 0,
  });
  final String phone;

  @override
  List<Object?> get props => [...super.props, phone];
}

class PhoneVerificationSuccess extends PhoneVerificationState {
  const PhoneVerificationSuccess();
}

class PhoneVerificationError extends PhoneVerificationState {
  const PhoneVerificationError({
    required this.failure,
    required this.bannerMessage,
    this.phone,
    super.resendCooldownSeconds = 0,
  });

  final Failure failure;
  final String bannerMessage;
  final String? phone;

  @override
  List<Object?> get props => [
    ...super.props,
    failure,
    bannerMessage,
    phone,
  ];
}

/// ForgotPasswordState — drives the email-entry sheet on the sign-in page.
sealed class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();
  @override
  List<Object?> get props => [];
}

class ForgotPasswordIdle extends ForgotPasswordState {
  const ForgotPasswordIdle();
}

class ForgotPasswordSubmitting extends ForgotPasswordState {
  const ForgotPasswordSubmitting();
}

/// Server has accepted the request — UI shows the neutral "if your email is on
/// file…" message. Holds the submitted email so the reset page can pre-fill it.
class ForgotPasswordSent extends ForgotPasswordState {
  const ForgotPasswordSent(this.email);
  final String email;
  @override
  List<Object?> get props => [email];
}

class ForgotPasswordError extends ForgotPasswordState {
  const ForgotPasswordError({
    required this.failure,
    required this.bannerMessage,
  });
  final Failure failure;
  final String bannerMessage;
  @override
  List<Object?> get props => [failure, bannerMessage];
}

/// ResetPasswordState — drives the reset page (code + new-password fields).
sealed class ResetPasswordState extends Equatable {
  const ResetPasswordState();
  @override
  List<Object?> get props => [];
}

class ResetPasswordIdle extends ResetPasswordState {
  const ResetPasswordIdle();
}

class ResetPasswordSubmitting extends ResetPasswordState {
  const ResetPasswordSubmitting();
}

class ResetPasswordSuccess extends ResetPasswordState {
  const ResetPasswordSuccess();
}

class ResetPasswordError extends ResetPasswordState {
  const ResetPasswordError({
    required this.failure,
    required this.bannerMessage,
  });
  final Failure failure;
  final String bannerMessage;
  @override
  List<Object?> get props => [failure, bannerMessage];
}
