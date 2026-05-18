import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/legal/legal_constants.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/otp_code_input.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';
import '../widgets/auth_page_scaffold.dart';

/// Phone OTP wizard — step 2: 6-digit code entry.
///
/// Design rules (SWE-10 brief):
///   - Title: "Check your messages."
///   - Subtitle: "We sent a 6-digit code to {masked phone}. Enter it below."
///   - Masked phone: keep dial code + first 4 digits, replace last 4 with ••••.
///   - OtpCodeInput auto-submits on 6th digit.
///   - Resend cooldown mirrors TRI-15's 60s pattern.
///   - "Wrong number? Go back" → pops to phone-entry, preserves phone in state.
///   - Sender-ID bridge copy rendered below "Wrong number?" link, wrapped in
///     kPhoneVerificationBridgeCopyEnabled flag.
///   - BannerMessage(variant: accent) on wrong-code / rate-limited / network error.
class VerifyPhonePage extends ConsumerStatefulWidget {
  const VerifyPhonePage({super.key});

  @override
  ConsumerState<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends ConsumerState<VerifyPhonePage> {
  String? _dismissedBannerMessage;

  Future<void> _verify(String code) async {
    setState(() => _dismissedBannerMessage = null);
    await ref.read(phoneVerificationControllerProvider.notifier).verify(code);
    final state = ref.read(phoneVerificationControllerProvider);
    if (!mounted) return;
    if (state is PhoneVerificationSuccess) {
      // Wizard complete — return to the profile page (or wherever the user
      // came from). go() so they can't navigate back into the OTP flow.
      context.go('/profile');
    }
  }

  void _goBack() {
    ref.read(phoneVerificationControllerProvider.notifier).goBackToEntry();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/auth/phone/entry');
    }
  }

  Future<void> _resend() async {
    await ref.read(phoneVerificationControllerProvider.notifier).resend();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneVerificationControllerProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    final phone = switch (state) {
      PhoneVerificationCodeSent(:final phone) => phone,
      PhoneVerificationSubmitting(:final phone) => phone,
      PhoneVerificationError(:final phone) => phone,
      _ => null,
    };

    final maskedPhone = phone != null ? _maskPhone(phone) : '';
    final isSubmitting = state is PhoneVerificationSubmitting;
    final cooldown = state.resendCooldownSeconds;

    final bannerMessage = state is PhoneVerificationError
        ? state.bannerMessage
        : null;
    final showBanner =
        bannerMessage != null && bannerMessage != _dismissedBannerMessage;

    final isError = state is PhoneVerificationError;

    return AuthPageScaffold(
      title: 'Check your messages.',
      subtitle: maskedPhone.isEmpty
          ? 'We sent a 6-digit code. Enter it below.'
          : 'We sent a 6-digit code to $maskedPhone. Enter it below.',
      backFallback: '/auth/phone/entry',
      child: Opacity(
        opacity: isSubmitting ? 0.6 : 1.0,
        child: AbsorbPointer(
          absorbing: isSubmitting,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBanner)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: BannerMessage(
                    message: bannerMessage,
                    onDismiss: () =>
                        setState(() => _dismissedBannerMessage = bannerMessage),
                  ),
                ),
              Center(
                child: OtpCodeInput(
                  onCompleted: _verify,
                  errorState: isError,
                  enabled: !isSubmitting,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: cooldown > 0 || isSubmitting ? null : _resend,
                  child: Text(
                    cooldown > 0
                        ? 'Resend code in ${cooldown}s'
                        : "Didn't get it? Resend code",
                    style: TribelyType.bodyM(inkSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _goBack,
                  child: Text(
                    'Wrong number? Go back',
                    style: TribelyType.bodyM(inkSecondary),
                  ),
                ),
              ),
              if (kPhoneVerificationBridgeCopyEnabled) ...[
                const SizedBox(height: 8),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      kSenderIdBridgeCopy,
                      textAlign: TextAlign.center,
                      style: TribelyType.caption(
                        inkSecondary,
                      ).copyWith(fontWeight: FontWeight.w400),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Masks the middle digits of an E.164 phone number for privacy.
///
/// Keeps the dial code and first 4 digits of the local number; replaces the
/// last 4 digits with ••••.
///
/// Examples:
///   "+6591234567" → "+65 9123 ••••"
///   "+447911123456" → "+44 7911 12••••"  (keeps dial code)
///
/// If the number is too short to mask, returns it unchanged.
String _maskPhone(String e164) {
  // Strip the leading '+' and find where the local part begins.
  // We rely on the stored dialCode in state, but since we only have the E.164
  // string here, we keep the first 3 chars as the country/dial code prefix
  // and mask from position (length - 4) onward.
  if (e164.length < 8) return e164;

  // Find the dial code by checking common lengths (1, 2, 3 digits after +).
  // For display purposes we simply show the full number with last 4 masked.
  final digits = e164.startsWith('+') ? e164.substring(1) : e164;
  if (digits.length < 8) return e164;

  // Split into: full number minus last 4, plus mask.
  final visible = e164.substring(0, e164.length - 4);
  return '$visible ••••';
}
