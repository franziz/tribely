import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/start_phone_verification_usecase.dart';
import '../../domain/usecases/verify_phone_usecase.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

/// Drives the two-step phone OTP wizard (PhoneEntryPage → VerifyPhonePage).
///
/// State machine:
///   Idle
///    ↓ start(phone)
///   Sending
///    ↓ success
///   CodeSent(phone, cooldown=60)
///    ↓ verify(code)
///   Submitting(phone)
///    ↓ success
///   Success
///    ↓ error path
///   Error(bannerMessage, phone?, cooldown?)
///
/// Cooldown: 60-second countdown after a successful send, mirroring the
/// server's 1/min/number rate limit. Pattern identical to VerifyEmailController.
class PhoneVerificationController extends Notifier<PhoneVerificationState> {
  Timer? _cooldownTimer;

  @override
  PhoneVerificationState build() {
    ref.onDispose(() => _cooldownTimer?.cancel());
    return const PhoneVerificationIdle();
  }

  /// Called by PhoneEntryPage on "Send code" tap. [phone] must be E.164,
  /// e.g. "+6591234567".
  Future<void> start(String phone) async {
    if (state is PhoneVerificationSending) return;
    state = const PhoneVerificationSending();

    final useCase = ref.read(startPhoneVerificationUseCaseProvider);
    final params = StartPhoneParams(phone: phone);
    final result = await useCase(params);
    result.match(
      (failure) {
        state = PhoneVerificationError(
          failure: failure,
          bannerMessage: _bannerFor(failure),
        );
      },
      (_) {
        state = PhoneVerificationCodeSent(phone: phone);
        _startCooldown(phone);
      },
    );
  }

  /// Re-send the OTP. Only callable when cooldown has expired.
  Future<void> resend() async {
    final phone = _currentPhone;
    if (phone == null) return;
    if (state.resendCooldownSeconds > 0) return;

    state = const PhoneVerificationSending();

    final useCase = ref.read(startPhoneVerificationUseCaseProvider);
    final result = await useCase(StartPhoneParams(phone: phone));
    result.match(
      (failure) {
        state = PhoneVerificationError(
          failure: failure,
          bannerMessage: _bannerFor(failure),
          phone: phone,
        );
      },
      (_) {
        state = PhoneVerificationCodeSent(phone: phone);
        _startCooldown(phone);
      },
    );
  }

  /// Called by VerifyPhonePage's OtpCodeInput.onCompleted and the submit
  /// button. [code] is the 6-digit string.
  Future<void> verify(String code) async {
    final phone = _currentPhone;
    if (phone == null) return;
    if (state is PhoneVerificationSubmitting) return;
    final cooldown = state.resendCooldownSeconds;
    state = PhoneVerificationSubmitting(
      phone: phone,
      resendCooldownSeconds: cooldown,
    );

    final useCase = ref.read(verifyPhoneUseCaseProvider);
    final params = VerifyPhoneParams(phone: phone, code: code);
    final result = await useCase(params);
    result.match(
      (failure) {
        state = PhoneVerificationError(
          failure: failure,
          bannerMessage: _bannerFor(failure),
          phone: phone,
          resendCooldownSeconds: cooldown,
        );
      },
      (user) {
        _cooldownTimer?.cancel();
        ref.read(sessionControllerProvider.notifier).setUser(user);
        state = const PhoneVerificationSuccess();
      },
    );
  }

  /// Allows the user to go back to PhoneEntryPage from VerifyPhonePage while
  /// keeping the entered phone (the back button relies on controller state).
  void goBackToEntry() {
    final phone = _currentPhone;
    _cooldownTimer?.cancel();
    state = PhoneVerificationIdle(
      resendCooldownSeconds: phone != null ? state.resendCooldownSeconds : 0,
    );
  }

  String? get _currentPhone {
    final s = state;
    return switch (s) {
      PhoneVerificationCodeSent(:final phone) => phone,
      PhoneVerificationSubmitting(:final phone) => phone,
      PhoneVerificationError(:final phone) => phone,
      _ => null,
    };
  }

  void _startCooldown(String phone) {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.resendCooldownSeconds - 1;
      if (remaining <= 0) {
        timer.cancel();
        // Only reset cooldown, preserve the CodeSent state (user stays on the
        // verify-phone page).
        state = PhoneVerificationCodeSent(
          phone: phone,
          resendCooldownSeconds: 0,
        );
        return;
      }
      state = switch (state) {
        PhoneVerificationIdle() => PhoneVerificationIdle(
          resendCooldownSeconds: remaining,
        ),
        PhoneVerificationSending() => PhoneVerificationSending(
          resendCooldownSeconds: remaining,
        ),
        PhoneVerificationCodeSent() => PhoneVerificationCodeSent(
          phone: phone,
          resendCooldownSeconds: remaining,
        ),
        PhoneVerificationSubmitting() => PhoneVerificationSubmitting(
          phone: phone,
          resendCooldownSeconds: remaining,
        ),
        PhoneVerificationSuccess() => const PhoneVerificationSuccess(),
        PhoneVerificationError(:final failure, :final bannerMessage) =>
          PhoneVerificationError(
            failure: failure,
            bannerMessage: bannerMessage,
            phone: phone,
            resendCooldownSeconds: remaining,
          ),
      };
    });
  }
}

String _bannerFor(Failure failure) {
  return switch (failure) {
    NetworkFailure() => "Couldn't reach Tribely. Check your connection.",
    SmsRateLimitedFailure() =>
      'You can only request 5 codes per hour per number. Try again later.',
    ServerFailure(:final statusCode) when statusCode == 429 =>
      'Too many attempts. Try again in a minute.',
    ServerFailure() => "Something's off on our end. Give it a moment.",
    ValidationFailure() => failure.message,
    AuthFailure() => failure.message,
    EmailNotVerifiedFailure() => failure.message,
    PhoneNotVerifiedFailure() => failure.message,
    NotFoundFailure() => failure.message,
    CapacityFullFailure() => failure.message,
    ConflictFailure() => failure.message,
    FirstEventMustBePublicFailure() => failure.message,
    EditWindowExpiredFailure() => failure.message,
    TargetNotFoundFailure() => failure.message,
    TargetTypeNotImplementedFailure() => failure.message,
    UnknownFailure() => failure.message,
  };
}
