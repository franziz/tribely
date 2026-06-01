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
import '../../../../core/widgets/auth_page_scaffold.dart';
import '../widgets/password_field.dart';

/// Reset-password page. Reached from the forgot-password sheet on /sign-in;
/// receives the email as a query parameter so the user only enters the code +
/// new password. On success, snackbar + route back to /sign-in.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({this.email, super.key});
  final String? email;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _codeError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String s) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);

  Future<void> _submit() async {
    final email = _email.text.trim();
    final code = _code.text.trim();
    final password = _password.text;

    String? emailErr;
    String? codeErr;
    String? passwordErr;
    if (!_looksLikeEmail(email)) emailErr = "That doesn't look like an email.";
    if (!RegExp(r'^\d{6}$').hasMatch(code)) codeErr = 'Enter the 6-digit code.';
    if (password.length < 8) {
      passwordErr = 'Password must be at least 8 characters.';
    }
    setState(() {
      _emailError = emailErr;
      _codeError = codeErr;
      _passwordError = passwordErr;
    });
    if (emailErr != null || codeErr != null || passwordErr != null) return;

    await ref
        .read(resetPasswordControllerProvider.notifier)
        .submit(email: email, code: code, newPassword: password);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resetPasswordControllerProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    // On success, defer navigation + snackbar to a post-frame so the
    // controller state is visible to widget tests before we leave the page.
    ref.listen<ResetPasswordState>(resetPasswordControllerProvider, (
      previous,
      next,
    ) {
      if (next is ResetPasswordSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated. Sign in to continue.'),
          ),
        );
        context.go('/sign-in');
      }
    });

    final submitting = state is ResetPasswordSubmitting;
    final success = state is ResetPasswordSuccess;
    final bannerMessage = state is ResetPasswordError
        ? state.bannerMessage
        : null;

    final buttonState = success
        ? PrimaryButtonState.success
        : submitting
        ? PrimaryButtonState.loading
        : PrimaryButtonState.idle;

    return AuthPageScaffold(
      title: 'Set a new password.',
      subtitle: 'Enter the 6-digit code from your email and a new password.',
      backFallback: '/sign-in',
      child: Opacity(
        opacity: submitting ? 0.6 : 1.0,
        child: AbsorbPointer(
          absorbing: submitting,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bannerMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: BannerMessage(message: bannerMessage),
                ),
              TribelyTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                errorText: _emailError,
                enabled: !submitting,
              ),
              const SizedBox(height: 16),
              TribelyTextField(
                controller: _code,
                label: '6-digit reset code',
                helper: '6 digits.',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.oneTimeCode],
                errorText: _codeError,
                enabled: !submitting,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: 'New password',
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                enabled: !submitting,
                errorText: _passwordError,
              ),
              const SizedBox(height: 24),
              ListenableBuilder(
                listenable: Listenable.merge([_email, _code, _password]),
                builder: (context, _) {
                  final canSubmit =
                      _email.text.trim().isNotEmpty &&
                      _code.text.trim().isNotEmpty &&
                      _password.text.isNotEmpty;
                  return PrimaryButton(
                    label: 'Reset password',
                    onPressed: canSubmit ? _submit : null,
                    state: buttonState,
                  );
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: submitting ? null : () => context.go('/sign-in'),
                  child: Text(
                    'Back to sign in',
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
