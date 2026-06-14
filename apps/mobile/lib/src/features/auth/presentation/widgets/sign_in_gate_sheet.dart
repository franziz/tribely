import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tribely_text_field.dart';
import '../controllers/sign_in_gate_controller.dart';
import '../pages/forgot_password_sheet.dart';
import '../state/sign_in_gate_state.dart';
import '../state/sign_in_intent.dart';
import '../string_assets/sign_in_gate_copy.dart';
import 'password_field.dart';

/// Shows the context-aware sign-in gate as a modal bottom sheet.
///
/// Returns `true` if the user authenticated successfully, `false` if they
/// dismissed the sheet without authenticating. The CALLER (Briefs B/C) reads
/// this result and resumes the intended action on `true`.
///
/// ```dart
/// final didSignIn = await showSignInGateSheet(
///   context,
///   intent: SignInIntent.createEvent(),
/// );
/// if (didSignIn == true) {
///   // resume the action
/// }
/// ```
Future<bool> showSignInGateSheet(
  BuildContext context, {
  required SignInIntent intent,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => _SignInGateSheet(intent: intent),
  );
  // A null result means the user dragged/tapped the scrim to dismiss.
  return result ?? false;
}

class _SignInGateSheet extends ConsumerStatefulWidget {
  const _SignInGateSheet({required this.intent});
  final SignInIntent intent;

  @override
  ConsumerState<_SignInGateSheet> createState() => _SignInGateSheetState();
}

class _SignInGateSheetState extends ConsumerState<_SignInGateSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Request focus on the email field once the sheet has settled so the
    // keyboard appears on open. TribelyTextField manages its own FocusNode
    // internally, so we advance to the first focusable descendant via
    // nextFocus rather than holding an external FocusNode reference.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).nextFocus();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  SignInGateController get _controller =>
      ref.read(signInGateControllerProvider(widget.intent).notifier);

  Future<void> _submit() async {
    await _controller.submit(
      email: _email.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surfaceHigh = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

    final state = ref.watch(signInGateControllerProvider(widget.intent));
    final submitting = state is SignInGateSubmitting;
    final success = state is SignInGateSuccess;
    final error = state is SignInGateError ? state : null;

    // Auto-dismiss + haptic on success.
    ref.listen<SignInGateState>(signInGateControllerProvider(widget.intent), (
      _,
      next,
    ) {
      if (next is SignInGateSuccess) {
        HapticFeedback.mediumImpact();
        Future.delayed(TribelyMotion.short, () {
          if (context.mounted) Navigator.of(context).pop(true);
        });
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: surfaceHigh,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _FormBody(
            intent: widget.intent,
            emailController: _email,
            passwordController: _password,
            submitting: submitting,
            success: success,
            error: error,
            ink: ink,
            inkSecondary: inkSecondary,
            accent: accent,
            onSubmit: _submit,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form body
// ---------------------------------------------------------------------------

class _FormBody extends ConsumerWidget {
  const _FormBody({
    required this.intent,
    required this.emailController,
    required this.passwordController,
    required this.submitting,
    required this.success,
    required this.error,
    required this.ink,
    required this.inkSecondary,
    required this.accent,
    required this.onSubmit,
  });

  final SignInIntent intent;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool submitting;
  final bool success;
  final SignInGateError? error;
  final Color ink;
  final Color inkSecondary;
  final Color accent;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Opacity(
      opacity: submitting ? 0.6 : 1.0,
      child: AbsorbPointer(
        absorbing: submitting,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
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
              const SizedBox(height: 12),

              // Close [X]
              Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  label: 'Close sign-in sheet',
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(Icons.close, color: inkSecondary),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                ),
              ),

              // Headline
              _Headline(intent: intent, ink: ink),
              const SizedBox(height: 24),

              // Auth-error banner (liveRegion so screen reader announces it)
              if (error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: BannerMessage(message: error!.message),
                ),
                const SizedBox(height: 16),
              ],

              // Email field — keyboard appears on open via initState.nextFocus()
              TribelyTextField(
                controller: emailController,
                label: SignInGateCopy.emailLabel,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: !submitting,
              ),
              const SizedBox(height: 20),

              // Password field
              PasswordField(
                controller: passwordController,
                label: SignInGateCopy.passwordLabel,
                autofillHints: const [AutofillHints.password],
                enabled: !submitting,
                onSubmitted: (_) => onSubmit(),
              ),

              // Forgot password — right-aligned, min 48×48 tap target
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: submitting
                      ? null
                      : () => showForgotPasswordSheet(
                          context,
                          prefilledEmail: emailController.text.trim().isEmpty
                              ? null
                              : emailController.text.trim(),
                        ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    SignInGateCopy.forgotPasswordLink,
                    style: TribelyType.caption(inkSecondary),
                  ),
                ),
              ),

              // Sign in CTA — disabled until both fields non-empty
              ListenableBuilder(
                listenable: Listenable.merge([
                  emailController,
                  passwordController,
                ]),
                builder: (context, _) {
                  final canSubmit =
                      emailController.text.trim().isNotEmpty &&
                      passwordController.text.isNotEmpty;
                  final buttonState = success
                      ? PrimaryButtonState.success
                      : submitting
                      ? PrimaryButtonState.loading
                      : PrimaryButtonState.idle;
                  return PrimaryButton(
                    label: SignInGateCopy.primaryCta,
                    onPressed: canSubmit && !submitting && !success
                        ? onSubmit
                        : null,
                    state: buttonState,
                  );
                },
              ),
              const SizedBox(height: 24),

              // "New here? Create account" — RichText, accessible label
              Center(
                child: Semantics(
                  label: 'New here? Create account',
                  child: TextButton(
                    onPressed: submitting
                        ? null
                        : () {
                            Navigator.of(context).pop(false);
                            context.go('/sign-up');
                          },
                    child: RichText(
                      text: TextSpan(
                        style: TribelyType.bodyM(inkSecondary),
                        children: [
                          const TextSpan(
                            text: SignInGateCopy.createAccountPrefix,
                          ),
                          TextSpan(
                            text: SignInGateCopy.createAccountAction,
                            style: TribelyType.bodyM(
                              accent,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
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

// ---------------------------------------------------------------------------
// Headline — context-aware based on SignInIntent
// ---------------------------------------------------------------------------

class _Headline extends StatelessWidget {
  const _Headline({required this.intent, required this.ink});

  final SignInIntent intent;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return switch (intent) {
      SignInIntentRequestJoin(:final eventTitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SignInGateCopy.joinHeadlineLine1,
            style: TribelyType.displayM(ink),
          ),
          Text(
            '"$eventTitle"',
            style: TribelyType.displayM(ink),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      SignInIntentCreateEvent() => Text(
        SignInGateCopy.createHeadline,
        style: TribelyType.displayM(ink),
      ),
      SignInIntentGeneral() => Text(
        SignInGateCopy.generalHeadline,
        style: TribelyType.displayM(ink),
      ),
      SignInIntentWriteReview() => Text(
        SignInGateCopy.reviewHeadline,
        style: TribelyType.displayM(ink),
      ),
    };
  }
}
