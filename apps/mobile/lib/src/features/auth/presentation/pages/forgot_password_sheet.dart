import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tribely_text_field.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

/// Bottom sheet entry to the password-reset flow. Asks for an email, hits
/// `/auth/forgot-password`, and on success ("If your email is on file…")
/// routes to the reset page where the user enters the 6-digit code from
/// their inbox + the new password.
Future<void> showForgotPasswordSheet(
  BuildContext context, {
  String? prefilledEmail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ForgotPasswordSheet(prefilledEmail: prefilledEmail),
  );
}

class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  const _ForgotPasswordSheet({this.prefilledEmail});
  final String? prefilledEmail;

  @override
  ConsumerState<_ForgotPasswordSheet> createState() =>
      _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  late final TextEditingController _email;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.prefilledEmail ?? '');
    // Reset controller state in case a prior flow left it dirty.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(forgotPasswordControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String s) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);

  Future<void> _submit() async {
    final value = _email.text.trim();
    if (!_looksLikeEmail(value)) {
      setState(() => _emailError = "That doesn't look like an email.");
      return;
    }
    setState(() => _emailError = null);
    await ref.read(forgotPasswordControllerProvider.notifier).submit(value);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    final state = ref.watch(forgotPasswordControllerProvider);
    final submitting = state is ForgotPasswordSubmitting;
    final sent = state is ForgotPasswordSent;
    final bannerMessage = state is ForgotPasswordError
        ? state.bannerMessage
        : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          28,
          12,
          28,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: inkSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (sent) ...[
              Text('Check your inbox.', style: TribelyType.headline(ink)),
              const SizedBox(height: 12),
              Text(
                "If your email is on file, you'll get a 6-digit reset code shortly.",
                style: TribelyType.bodyL(inkSecondary),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Enter code',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(
                    Uri(
                      path: '/reset-password',
                      queryParameters: {'email': state.email},
                    ).toString(),
                  );
                },
              ),
            ] else ...[
              Text('Reset your password.', style: TribelyType.headline(ink)),
              const SizedBox(height: 12),
              Text(
                'Enter your email and we’ll send you a 6-digit reset code.',
                style: TribelyType.bodyL(inkSecondary),
              ),
              const SizedBox(height: 20),
              if (bannerMessage != null) ...[
                BannerMessage(message: bannerMessage),
                const SizedBox(height: 16),
              ],
              TribelyTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                errorText: _emailError,
                enabled: !submitting,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: _email,
                builder: (context, _) {
                  final canSubmit = _email.text.trim().isNotEmpty;
                  return PrimaryButton(
                    label: 'Send reset code',
                    onPressed: canSubmit && !submitting ? _submit : null,
                    state: submitting
                        ? PrimaryButtonState.loading
                        : PrimaryButtonState.idle,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
