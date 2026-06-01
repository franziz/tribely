import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tribely_text_field.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';
import '../widgets/auth_dismissible_banner.dart';
import 'package:tribely_mobile/src/core/widgets/auth_page_scaffold.dart';
import '../widgets/password_field.dart';
import 'forgot_password_sheet.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({this.prefilledEmail, super.key});
  final String? prefilledEmail;

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  late final TextEditingController _email;
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.prefilledEmail ?? '');
    // No setState listeners on the controllers — keystroke updates are
    // localized in the widgets that need them (submit button via
    // ListenableBuilder, password show/hide via PasswordField's own state).
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _validateEmailOnBlur() {
    final v = _email.text.trim();
    setState(() {
      if (v.isEmpty) {
        _emailError = 'Email address is required.';
      } else if (!_looksLikeEmail(v)) {
        _emailError = "That doesn't look like an email.";
      } else {
        _emailError = null;
      }
    });
  }

  bool _looksLikeEmail(String s) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);

  Future<void> _submit() async {
    _validateEmailOnBlur();
    if (_emailError != null || _password.text.isEmpty) {
      setState(
        () => _passwordError = _password.text.isEmpty
            ? 'Password is required.'
            : null,
      );
      return;
    }
    setState(() => _passwordError = null);
    await ref
        .read(signInControllerProvider.notifier)
        .submit(email: _email.text.trim(), password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      title: 'Welcome back.',
      subtitle: 'Sign in to your Tribely account.',
      child: _SignInForm(
        emailController: _email,
        passwordController: _password,
        emailError: _emailError,
        passwordError: _passwordError,
        onValidateEmail: _validateEmailOnBlur,
        onSubmit: _submit,
      ),
    );
  }
}

/// Form body — split out of the page so its rebuilds are scoped tightly.
/// Watches the SignInController state for submission/success transitions
/// (the rest of the page chrome doesn't need to know about those).
class _SignInForm extends ConsumerWidget {
  const _SignInForm({
    required this.emailController,
    required this.passwordController,
    required this.emailError,
    required this.passwordError,
    required this.onValidateEmail,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? emailError;
  final String? passwordError;
  final VoidCallback onValidateEmail;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    final formState = ref.watch(signInControllerProvider);
    final submitting = formState is AuthFormSubmitting;
    final success = formState is AuthFormSuccess;
    final buttonState = success
        ? PrimaryButtonState.success
        : submitting
        ? PrimaryButtonState.loading
        : PrimaryButtonState.idle;

    return Opacity(
      opacity: submitting ? 0.6 : 1.0,
      child: AbsorbPointer(
        absorbing: submitting,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthDismissibleBanner(
              watch: (ref) => ref.watch(signInControllerProvider),
            ),
            Focus(
              onFocusChange: (has) {
                if (!has) onValidateEmail();
              },
              child: TribelyTextField(
                controller: emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                errorText: emailError,
                enabled: !submitting,
              ),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: passwordController,
              label: 'Password',
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => onSubmit(),
              enabled: !submitting,
              errorText: passwordError,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showForgotPasswordSheet(
                  context,
                  prefilledEmail: emailController.text.trim().isEmpty
                      ? null
                      : emailController.text.trim(),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  minimumSize: const Size(48, 48),
                ),
                child: Text(
                  'Forgot password?',
                  style: TribelyType.caption(inkSecondary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Listens to BOTH controllers — the only thing that rebuilds
            // on every keystroke is this button. The rest of the form
            // (and the entire scaffold above) stays still.
            ListenableBuilder(
              listenable: Listenable.merge([
                emailController,
                passwordController,
              ]),
              builder: (context, _) {
                final canSubmit =
                    emailController.text.trim().isNotEmpty &&
                    passwordController.text.isNotEmpty;
                return PrimaryButton(
                  label: 'Sign in',
                  onPressed: canSubmit ? onSubmit : null,
                  state: buttonState,
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: TribelyType.caption(inkSecondary)),
                ),
                Expanded(child: Divider(color: border)),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                side: BorderSide(color: border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue with Google',
                    style: TribelyType.button(inkSecondary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Coming soon',
                      style: TribelyType.caption(inkSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: TextButton(
                onPressed: () => context.go('/sign-up'),
                child: RichText(
                  text: TextSpan(
                    style: TribelyType.bodyM(inkSecondary),
                    children: [
                      const TextSpan(text: 'New to Tribely?  '),
                      TextSpan(
                        text: 'Create an account',
                        style: TribelyType.bodyM(
                          accent,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
