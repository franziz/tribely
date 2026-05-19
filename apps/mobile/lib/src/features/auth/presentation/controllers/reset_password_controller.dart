import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

/// Drives the reset-password page. On success the server has invalidated all
/// of the user's sessions — the UI surfaces a snackbar then routes back to
/// /sign-in so the user re-authenticates with the new password.
class ResetPasswordController extends Notifier<ResetPasswordState> {
  @override
  ResetPasswordState build() => const ResetPasswordIdle();

  Future<void> submit({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (state is ResetPasswordSubmitting) return;
    state = const ResetPasswordSubmitting();

    final useCase = ref.read(resetPasswordUseCaseProvider);
    final result = await useCase(
      ResetPasswordParams(email: email, code: code, newPassword: newPassword),
    );
    result.match(
      (failure) {
        state = ResetPasswordError(
          failure: failure,
          bannerMessage: _bannerFor(failure),
        );
      },
      (_) {
        state = const ResetPasswordSuccess();
      },
    );
  }
}

String _bannerFor(Failure failure) {
  return switch (failure) {
    NetworkFailure() => "Couldn't reach Tribely. Check your connection.",
    ServerFailure(:final statusCode) when statusCode == 429 =>
      'Too many attempts. Try again in a minute.',
    ServerFailure() => "Something's off on our end. Give it a moment.",
    EmailNotVerifiedFailure() => failure.message,
    PhoneNotVerifiedFailure() => failure.message,
    AuthFailure() => failure.message,
    // The server collapses all reset-time errors (unknown email, bad code,
    // expired token) into a single 400 with this message — keeps the
    // enumeration surface clean.
    ValidationFailure() => failure.message,
    NotFoundFailure() => failure.message,
    CapacityFullFailure() => failure.message,
    ConflictFailure() => failure.message,
    FirstEventMustBePublicFailure() => failure.message,
    SmsRateLimitedFailure() => failure.message,
    EditWindowExpiredFailure() => failure.message,
    TargetNotFoundFailure() => failure.message,
    TargetTypeNotImplementedFailure() => failure.message,
    UnknownFailure() => failure.message,
  };
}
