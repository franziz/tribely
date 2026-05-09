import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/banner_message.dart';
import '../state/auth_state.dart';

/// Banner that watches an auth form-state provider and renders a coral
/// banner whenever it carries an error message. Self-contained:
///   - Owns its own "dismissed" state (per-message, so a new error after
///     a dismiss re-shows the banner).
///   - Handles the "Sign in instead →" action when the form state suggests
///     pre-filling sign-in with an email (sign-up's 409 conflict path).
///
/// Caller passes a [watch] closure that returns the current AuthFormState
/// for whichever provider the page uses. This avoids depending on the
/// non-exported `ProviderListenable` type and keeps the API explicit:
///
/// ```dart
/// AuthDismissibleBanner(
///   watch: (ref) => ref.watch(signInControllerProvider),
/// )
/// ```
typedef AuthFormStateWatcher = AuthFormState Function(WidgetRef ref);

class AuthDismissibleBanner extends ConsumerStatefulWidget {
  const AuthDismissibleBanner({required this.watch, super.key});

  final AuthFormStateWatcher watch;

  @override
  ConsumerState<AuthDismissibleBanner> createState() =>
      _AuthDismissibleBannerState();
}

class _AuthDismissibleBannerState extends ConsumerState<AuthDismissibleBanner> {
  String? _dismissedMessage;

  @override
  Widget build(BuildContext context) {
    final state = widget.watch(ref);
    final message = state is AuthFormError ? state.bannerMessage : null;
    if (message == null || message == _dismissedMessage) {
      return const SizedBox.shrink();
    }

    final suggestion = state is AuthFormError
        ? state.suggestSignInWithEmail
        : null;
    final action = suggestion != null
        ? BannerAction(
            label: 'Sign in instead →',
            onTap: () => context.go(
              '/sign-in?email=${Uri.encodeQueryComponent(suggestion)}',
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: BannerMessage(
        message: message,
        action: action,
        onDismiss: () => setState(() => _dismissedMessage = message),
      ),
    );
  }
}
