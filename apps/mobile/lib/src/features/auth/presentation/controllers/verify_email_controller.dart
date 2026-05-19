import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/verify_email_usecase.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

/// Drives `/verify-email`. Holds the submit/resend state and a 60-second
/// cooldown timer that mirrors the server's `1/min/user` rate limit on
/// `POST /auth/resend-verification` — without it, hammering "Resend" produces
/// noisy 429s instead of clean UI feedback.
class VerifyEmailController extends Notifier<VerifyEmailState> {
  Timer? _cooldownTimer;

  @override
  VerifyEmailState build() {
    ref.onDispose(() => _cooldownTimer?.cancel());
    return const VerifyEmailIdle();
  }

  Future<void> submit(String code) async {
    if (state is VerifyEmailSubmitting) return;
    final cooldown = state.resendCooldownSeconds;
    state = VerifyEmailSubmitting(resendCooldownSeconds: cooldown);

    final useCase = ref.read(verifyEmailUseCaseProvider);
    final result = await useCase(VerifyEmailParams(code: code));
    result.match(
      (failure) {
        state = VerifyEmailError(
          failure: failure,
          bannerMessage: _bannerFor(failure),
          resendCooldownSeconds: cooldown,
        );
      },
      (user) {
        ref.read(sessionControllerProvider.notifier).setUser(user);
        state = const VerifyEmailSuccess();
      },
    );
  }

  Future<void> resend() async {
    if (state.resendCooldownSeconds > 0) return;
    if (state is VerifyEmailResending) return;
    state = const VerifyEmailResending();

    final useCase = ref.read(resendVerificationUseCaseProvider);
    final result = await useCase(const NoParams());
    result.match(
      (failure) {
        state = VerifyEmailError(
          failure: failure,
          bannerMessage: _bannerFor(failure),
        );
      },
      (_) {
        state = const VerifyEmailResendSent();
        _startCooldown();
      },
    );
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.resendCooldownSeconds - 1;
      if (remaining <= 0) {
        timer.cancel();
        state = const VerifyEmailIdle();
        return;
      }
      state = switch (state) {
        VerifyEmailIdle() => VerifyEmailIdle(resendCooldownSeconds: remaining),
        VerifyEmailSubmitting() => VerifyEmailSubmitting(
          resendCooldownSeconds: remaining,
        ),
        VerifyEmailResending() => VerifyEmailResending(
          resendCooldownSeconds: remaining,
        ),
        VerifyEmailResendSent() => VerifyEmailResendSent(
          resendCooldownSeconds: remaining,
        ),
        VerifyEmailError(:final failure, :final bannerMessage) =>
          VerifyEmailError(
            failure: failure,
            bannerMessage: bannerMessage,
            resendCooldownSeconds: remaining,
          ),
        VerifyEmailSuccess() => const VerifyEmailSuccess(),
      };
    });
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
    SmsRateLimitedFailure() => failure.message,
    UnknownFailure() => failure.message,
  };
}
