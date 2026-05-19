import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/otp_code_input.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';
import '../widgets/auth_page_scaffold.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  String? _dismissedMessage;

  Future<void> _verify(String code) async {
    setState(() => _dismissedMessage = null);
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
    final cooldown = state.resendCooldownSeconds;

    final bannerMessage = state is VerifyEmailError
        ? state.bannerMessage
        : null;
    final showBanner =
        bannerMessage != null && bannerMessage != _dismissedMessage;

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
              Center(
                child: OtpCodeInput(
                  enabled: !submitting,
                  errorState: state is VerifyEmailError,
                  onCompleted: (code) => _verify(code),
                ),
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
