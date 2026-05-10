import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tribely_text_field.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';
import '../widgets/auth_page_scaffold.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _code = TextEditingController();
  String? _dismissedMessage;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.length != 6) return;
    await ref.read(verifyEmailControllerProvider.notifier).submit(code);
  }

  Future<void> _resend() async {
    await ref.read(verifyEmailControllerProvider.notifier).resend();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verifyEmailControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final email = session is SessionAuthenticated
        ? session.session.user.email
        : '';

    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    final submitting = state is VerifyEmailSubmitting;
    final resending = state is VerifyEmailResending;
    final success = state is VerifyEmailSuccess;
    final cooldown = state.resendCooldownSeconds;

    final bannerMessage = state is VerifyEmailError
        ? state.bannerMessage
        : null;
    final showBanner =
        bannerMessage != null && bannerMessage != _dismissedMessage;

    final buttonState = success
        ? PrimaryButtonState.success
        : submitting
        ? PrimaryButtonState.loading
        : PrimaryButtonState.idle;

    return AuthPageScaffold(
      title: 'Check your inbox.',
      subtitle: email.isEmpty
          ? 'We sent a 6-digit code. Enter it below to verify your email.'
          : 'We sent a 6-digit code to $email. Enter it below to verify your email.',
      backFallback: '/welcome',
      child: Opacity(
        opacity: submitting ? 0.6 : 1.0,
        child: AbsorbPointer(
          absorbing: submitting,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBanner)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: BannerMessage(
                    message: bannerMessage,
                    onDismiss: () =>
                        setState(() => _dismissedMessage = bannerMessage),
                  ),
                ),
              TribelyTextField(
                controller: _code,
                label: 'Verification code',
                helper: '6 digits.',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                onSubmitted: (_) => _submit(),
                enabled: !submitting,
              ),
              const SizedBox(height: 24),
              ListenableBuilder(
                listenable: _code,
                builder: (context, _) {
                  final digitsOnly = _code.text.replaceAll(RegExp(r'\D'), '');
                  return PrimaryButton(
                    label: 'Verify',
                    onPressed: digitsOnly.length == 6 ? _submit : null,
                    state: buttonState,
                  );
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: cooldown > 0 || resending ? null : _resend,
                  child: Text(
                    cooldown > 0
                        ? 'Resend code in ${cooldown}s'
                        : resending
                        ? 'Sending…'
                        : "Didn't get it? Resend code",
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
}

/// Number-only formatter for the 6-digit code input. Defined here for
/// future use if we swap the plain text field for a constrained one.
@visibleForTesting
class DigitsOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.replaceAll(RegExp(r'\D'), '');
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}
