import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/request_password_reset_usecase.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

/// Drives the forgot-password sheet on the sign-in page. Server returns 200
/// regardless of whether the email is on file (enumeration safety) — this
/// controller simply flips state through Submitting → Sent and lets the UI
/// show a neutral confirmation either way.
class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  @override
  ForgotPasswordState build() => const ForgotPasswordIdle();

  Future<void> submit(String email) async {
    if (state is ForgotPasswordSubmitting) return;
    state = const ForgotPasswordSubmitting();

    final useCase = ref.read(requestPasswordResetUseCaseProvider);
    final result = await useCase(RequestPasswordResetParams(email: email));
    result.match(
      (failure) {
        state = ForgotPasswordError(
          failure: failure,
          bannerMessage: _bannerFor(failure),
        );
      },
      (_) {
        state = ForgotPasswordSent(email);
      },
    );
  }

  void reset() {
    state = const ForgotPasswordIdle();
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
    ValidationFailure() => failure.message,
    NotFoundFailure() => failure.message,
    CapacityFullFailure() => failure.message,
    ConflictFailure() => failure.message,
    FirstEventMustBePublicFailure() => failure.message,
    UnknownFailure() => failure.message,
  };
}
