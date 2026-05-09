import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/password_strength.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tribely_text_field.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';
import '../widgets/auth_dismissible_banner.dart';
import '../widgets/auth_page_scaffold.dart';
import '../widgets/password_field.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _displayNameError;
  String? _emailError;

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _validateDisplayName() {
    final v = _displayName.text.trim();
    setState(() {
      if (v.length < 2) {
        _displayNameError = 'Display name must be at least 2 characters.';
      } else if (v.length > 50) {
        _displayNameError = 'Display name must be 50 characters or fewer.';
      } else {
        _displayNameError = null;
      }
    });
  }

  void _validateEmail() {
    final v = _email.text.trim();
    setState(() {
      if (v.isEmpty) {
        _emailError = 'Email address is required.';
      } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
        _emailError = "That doesn't look like an email.";
      } else {
        _emailError = null;
      }
    });
  }

  Future<void> _submit() async {
    _validateDisplayName();
    _validateEmail();
    if (_displayNameError != null ||
        _emailError != null ||
        _password.text.length < 8)
      return;
    await ref
        .read(signUpControllerProvider.notifier)
        .submit(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _displayName.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      title: 'Welcome.',
      subtitle: 'Tell us a few things to get started.',
      child: _SignUpForm(
        displayNameController: _displayName,
        emailController: _email,
        passwordController: _password,
        displayNameError: _displayNameError,
        emailError: _emailError,
        onValidateDisplayName: _validateDisplayName,
        onValidateEmail: _validateEmail,
        onSubmit: _submit,
      ),
    );
  }
}

class _SignUpForm extends ConsumerWidget {
  const _SignUpForm({
    required this.displayNameController,
    required this.emailController,
    required this.passwordController,
    required this.displayNameError,
    required this.emailError,
    required this.onValidateDisplayName,
    required this.onValidateEmail,
    required this.onSubmit,
  });

  final TextEditingController displayNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? displayNameError;
  final String? emailError;
  final VoidCallback onValidateDisplayName;
  final VoidCallback onValidateEmail;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

    final formState = ref.watch(signUpControllerProvider);
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
              watch: (ref) => ref.watch(signUpControllerProvider),
            ),
            Focus(
              onFocusChange: (has) {
                if (!has) onValidateDisplayName();
              },
              child: TribelyTextField(
                controller: displayNameController,
                label: 'Display name',
                helper: 'This is what other travelers will see.',
                errorText: displayNameError,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                enabled: !submitting,
              ),
            ),
            const SizedBox(height: 16),
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
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => onSubmit(),
              enabled: !submitting,
            ),
            const SizedBox(height: 12),
            // Strength meter watches ONLY the password controller.
            ListenableBuilder(
              listenable: passwordController,
              builder: (context, _) => PasswordStrengthMeter(
                strength: assessPassword(passwordController.text),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "We'll never share your email. You can change anything later.",
              style: TribelyType.italicCaption(inkSecondary),
            ),
            const SizedBox(height: 16),
            // Submit button watches all three controllers — only this
            // button rebuilds on each keystroke.
            ListenableBuilder(
              listenable: Listenable.merge([
                displayNameController,
                emailController,
                passwordController,
              ]),
              builder: (context, _) {
                final canSubmit =
                    displayNameController.text.trim().isNotEmpty &&
                    emailController.text.trim().isNotEmpty &&
                    passwordController.text.length >= 8;
                return PrimaryButton(
                  label: 'Create account',
                  onPressed: canSubmit ? onSubmit : null,
                  state: buttonState,
                );
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => context.go('/sign-in'),
                child: RichText(
                  text: TextSpan(
                    style: TribelyType.bodyM(inkSecondary),
                    children: [
                      const TextSpan(text: 'Already have an account?  '),
                      TextSpan(
                        text: 'Sign in',
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
