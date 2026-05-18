import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/legal/legal_constants.dart';
import '../../../../core/widgets/country_picker_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tribely_text_field.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';
import '../widgets/auth_page_scaffold.dart';

/// Phone OTP wizard — step 1: country picker + phone number entry.
///
/// Design rules from SWE-10 brief:
///   - Country picker chip (flag + dial code) launches CountryPickerSheet.
///     Default = SG (+65).
///   - Phone TribelyTextField: no format-on-type (designer spec — breaks paste).
///   - Helper text: "Enter your local number — we add the country code."
///   - PDPA consent block rendered ABOVE "Send code" CTA.
///   - "Privacy Policy" inside consent is a tap-target → gotribely.com/privacy.
///   - Primary CTA: "Send code".
///   - Tertiary: "Skip for now →" — advances without backend call.
class PhoneEntryPage extends ConsumerStatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  ConsumerState<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends ConsumerState<PhoneEntryPage> {
  final _phoneController = TextEditingController();
  CountrySelection _country = (
    dialCode: '+65',
    flagEmoji: '🇸🇬',
    isoCode: 'SG',
  );
  String? _localValidationError;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _buildE164() {
    final local = _phoneController.text.trim();
    // Strip any leading 0 (common in SG local format: 091234567 → 91234567)
    final stripped = local.startsWith('0') ? local.substring(1) : local;
    return '${_country.dialCode}$stripped';
  }

  /// Returns null if valid, or an error message if not.
  String? _validate(String localNumber) {
    final stripped =
        localNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (stripped.isEmpty) return 'Please enter your phone number.';
    if (!RegExp(r'^\d{4,15}$').hasMatch(stripped)) {
      return 'Please enter a valid phone number.';
    }
    return null;
  }

  Future<void> _sendCode() async {
    final local = _phoneController.text.trim();
    final error = _validate(local);
    if (error != null) {
      setState(() => _localValidationError = error);
      return;
    }
    setState(() => _localValidationError = null);
    final phone = _buildE164();
    await ref.read(phoneVerificationControllerProvider.notifier).start(phone);

    // If start succeeded the state is CodeSent — navigate to verify page.
    final state = ref.read(phoneVerificationControllerProvider);
    if (!mounted) return;
    if (state is PhoneVerificationCodeSent) {
      unawaited(context.push('/auth/phone/verify'));
    }
  }

  void _skip() {
    // Advances the wizard without calling the backend. go() back to the
    // shell landing (/events) — same as tapping the Discover tab.
    context.go('/events');
  }

  // TODO(TRI-??): replace with launchUrl once `url_launcher` is added to
  // pubspec — same deferred pattern as discover_map_tab.dart attribution link.
  void _openPrivacyPolicy() {
    // no-op until url_launcher is added to pubspec.
  }

  Future<void> _pickCountry() async {
    final result = await showCountryPickerSheet(
      context,
      selectedIsoCode: _country.isoCode,
    );
    if (result != null) {
      setState(() => _country = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneVerificationControllerProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final borderSubtle = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final primaryColor = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;

    final isSending = state is PhoneVerificationSending;
    // Error from the server (not local validation) — shown as banner.
    final serverError = switch (state) {
      PhoneVerificationError(:final bannerMessage) => bannerMessage,
      _ => null,
    };

    return AuthPageScaffold(
      title: 'Add your number.',
      subtitle:
          "We'll send you a code to confirm it's yours. You can skip this for now.",
      backFallback: '/events',
      child: Opacity(
        opacity: isSending ? 0.6 : 1.0,
        child: AbsorbPointer(
          absorbing: isSending,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (serverError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildServerErrorBanner(serverError, dark),
                ),
              // Country picker chip
              GestureDetector(
                onTap: _pickCountry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderSubtle, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_country.flagEmoji}  ${_country.dialCode}',
                        style: TribelyType.bodyM(
                          dark
                              ? TribelyColors.nightInkPrimary
                              : TribelyColors.paperInkPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.expand_more,
                        size: 18,
                        color: inkSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Phone number field — no format-on-type (designer spec).
              TribelyTextField(
                controller: _phoneController,
                label: 'Phone number',
                helper: _localValidationError ??
                    'Enter your local number — we add the country code.',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sendCode(),
                enabled: !isSending,
              ),
              const SizedBox(height: 28),
              // PDPA consent block — must be visible above CTA, no scroll needed.
              _PdpaConsentBlock(
                inkSecondary: inkSecondary,
                primaryColor: primaryColor,
                onPrivacyPolicyTap: _openPrivacyPolicy,
              ),
              const SizedBox(height: 20),
              // Primary CTA
              ListenableBuilder(
                listenable: _phoneController,
                builder: (context, _) {
                  final hasText = _phoneController.text.trim().isNotEmpty;
                  return PrimaryButton(
                    label: 'Send code',
                    onPressed: hasText ? _sendCode : null,
                    state: isSending
                        ? PrimaryButtonState.loading
                        : PrimaryButtonState.idle,
                  );
                },
              ),
              const SizedBox(height: 20),
              // Tertiary skip link
              Center(
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip for now →',
                    style: TribelyType.bodyM(inkSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerErrorBanner(String message, bool dark) {
    // We import BannerMessage indirectly via core/widgets/banner_message.dart
    // but for a quick in-file approach we replicate the container style.
    // Actually: just use the standard approach from other pages.
    final accentColor = dark
        ? TribelyColors.nightAccent
        : TribelyColors.paperAccent;
    final accentSoft = dark
        ? TribelyColors.nightAccentSoft
        : TribelyColors.paperAccentSoft;
    final inkPrimary = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;

    return Container(
      decoration: BoxDecoration(
        color: accentSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Text(
        message,
        style: TribelyType.bodyM(
          inkPrimary,
        ).copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// PDPA consent block with inline "Privacy Policy" tap-target.
///
/// Must be displayed ABOVE the "Send code" CTA and visible without scrolling
/// on the smallest supported viewport (per SWE-10 spec + PDPA requirement).
class _PdpaConsentBlock extends StatelessWidget {
  const _PdpaConsentBlock({
    required this.inkSecondary,
    required this.primaryColor,
    required this.onPrivacyPolicyTap,
  });

  final Color inkSecondary;
  final Color primaryColor;
  final VoidCallback onPrivacyPolicyTap;

  @override
  Widget build(BuildContext context) {
    // Use the resolved consent copy with company name substituted.
    final body = resolveLegalCopy(kPdpaConsentBodyTemplate);

    // The consent copy contains "Privacy Policy" which must be a tap-target.
    // We split on it and rebuild as a RichText.
    const privacyText = 'Privacy Policy';
    final idx = body.indexOf(privacyText);

    if (idx < 0) {
      // Fallback: render as plain text if the template changed.
      return Text(body, style: TribelyType.caption(inkSecondary));
    }

    final before = body.substring(0, idx);
    final after = body.substring(idx + privacyText.length);

    return RichText(
      text: TextSpan(
        style: TribelyType.caption(inkSecondary),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: privacyText,
            style: TribelyType.caption(primaryColor).copyWith(
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()..onTap = onPrivacyPolicyTap,
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}
