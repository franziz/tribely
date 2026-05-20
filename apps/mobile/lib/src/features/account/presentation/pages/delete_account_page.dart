import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/legal/legal_constants.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/destructive_primary_button.dart';
import '../../../../core/widgets/primary_button.dart' show PrimaryButtonState;
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/tribely_text_field.dart';
import '../providers/account_providers.dart';
import '../state/delete_account_state.dart';

/// Confirmation surface for permanent account deletion.
///
/// AC2: typed-confirmation gate — CTA disabled until input matches 'DELETE'
///      exactly (case-sensitive).
/// AC3: disclosure paragraph + Privacy Policy link opens system browser.
/// AC4: on success, navigates to '/account-deleted' (stack-replacing go()).
/// AC7: recoverable failure — BannerMessage above heading, token retained.
/// AC8: verbatim designer copy (design spec §Screen 2).
///
/// Uses [ConsumerStatefulWidget] because it owns a [TextEditingController]
/// that must be disposed explicitly.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  late final TextEditingController _tokenController;

  /// Whether to show the mismatch hint below the input.
  ///
  /// Shown ONLY after the user commits the input (TextInputAction.done or
  /// focus-out), not during live typing. Page-local — not in controller state.
  bool _showMismatchHint = false;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController();
    _tokenController.addListener(_onTokenChanged);
  }

  void _onTokenChanged() {
    // Auto-uppercase: ensure the input is always uppercase as the user types,
    // since TribelyTextField does not expose textCapitalization. We mirror the
    // TextCapitalization.characters intent by uppercasing on every change.
    final raw = _tokenController.text;
    final upper = raw.toUpperCase();
    if (raw != upper) {
      _tokenController.value = _tokenController.value.copyWith(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
      // The recursive call from the above assignment will propagate the
      // uppercased value to the controller — return here to avoid double-fire.
      return;
    }
    ref.read(deleteAccountControllerProvider.notifier).updateToken(upper);
  }

  void _onInputCommitted(String _) {
    // Show mismatch hint after user submits the input via keyboard action.
    final state = ref.read(deleteAccountControllerProvider);
    if (!state.isTokenValid && _tokenController.text.isNotEmpty) {
      setState(() => _showMismatchHint = true);
    } else {
      setState(() => _showMismatchHint = false);
    }
  }

  @override
  void dispose() {
    _tokenController.removeListener(_onTokenChanged);
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(
      Uri.parse(kPrivacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deleteAccountControllerProvider);
    final controller = ref.read(deleteAccountControllerProvider.notifier);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final inkPrimary = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final primaryColor = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;

    // Navigate to the terminal screen on success. The route is registered in
    // Brief D. We emit the go() here so the page drives the nav transition.
    ref.listen<DeleteAccountState>(deleteAccountControllerProvider, (_, next) {
      if (next is DeleteAccountSuccess) {
        context.go('/account-deleted');
      }
    });

    // CTA is enabled only when token is valid AND we're not submitting.
    final bool ctaEnabled = switch (state) {
      DeleteAccountIdle(:final isTokenValid) => isTokenValid,
      DeleteAccountFailure(:final isTokenValid) => isTokenValid,
      DeleteAccountSubmitting() => false,
      DeleteAccountSuccess() => false,
    };

    final PrimaryButtonState buttonState = state is DeleteAccountSubmitting
        ? PrimaryButtonState.loading
        : PrimaryButtonState.idle;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: inkPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // --- Error banner (above heading, hidden when no failure) ---
                if (state is DeleteAccountFailure) ...[
                  _buildBanner(context, state, dark),
                  const SizedBox(height: 16),
                ],

                // --- Heading ---
                Text(
                  'Permanently delete your account?',
                  style: TribelyType.headline(inkPrimary),
                ),

                const SizedBox(height: 16),

                // --- Disclosure paragraph ---
                Text(
                  'This will permanently delete your profile, photos, and event history within '
                  '30 days. Your name and details will be removed from our systems. Some '
                  'activity records may be anonymised rather than deleted to preserve the '
                  'integrity of events you participated in.\n\n'
                  'This cannot be undone.',
                  style: TribelyType.bodyM(inkSecondary),
                ),

                const SizedBox(height: 8),

                // --- Privacy Policy link ---
                GestureDetector(
                  onTap: _openPrivacyPolicy,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Read our Privacy Policy for full details on data deletion.',
                      style: TribelyType.bodyM(primaryColor),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // --- Helper label above input ---
                Text(
                  'Type DELETE to confirm',
                  style: TribelyType.caption(inkSecondary),
                ),

                const SizedBox(height: 8),

                // --- Confirmation token input ---
                Semantics(
                  label:
                      'Confirmation input. Type the word DELETE in capital letters to confirm account deletion.',
                  child: TribelyTextField(
                    controller: _tokenController,
                    label: 'DELETE',
                    textInputAction: TextInputAction.done,
                    onSubmitted: _onInputCommitted,
                    enabled: state is! DeleteAccountSubmitting,
                    errorText: _showMismatchHint
                        ? 'Type exactly: DELETE'
                        : null,
                  ),
                ),

                const SizedBox(height: 24),

                // --- Destructive CTA ---
                Semantics(
                  label: switch (buttonState) {
                    PrimaryButtonState.loading =>
                      'Deleting account, please wait.',
                    _ when ctaEnabled =>
                      'Permanently delete account, button. Destructive action — this cannot be undone.',
                    _ =>
                      'Permanently delete account, button, disabled. Type DELETE to enable.',
                  },
                  excludeSemantics: true,
                  child: DestructivePrimaryButton(
                    label: 'Permanently delete account',
                    state: buttonState,
                    onPressed: ctaEnabled ? controller.submit : null,
                  ),
                ),

                const SizedBox(height: 12),

                // --- Cancel button ---
                SecondaryButton(
                  label: 'Cancel',
                  onPressed: () => context.pop(),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(
    BuildContext context,
    DeleteAccountFailure state,
    bool dark,
  ) {
    final String message;
    final BannerAction? action;

    switch (state.kind) {
      case DeleteAccountFailureKind.network:
        message = 'No connection. Check your internet and try again.';
        action = null;
      case DeleteAccountFailureKind.sessionExpired:
        message =
            'Your session has expired. Sign in again to delete your account.';
        action = BannerAction(
          label: 'Sign in →',
          onTap: () => context.go('/sign-in'),
        );
      case DeleteAccountFailureKind.server:
        message =
            'Something went wrong on our end. Please try again in a moment.';
        action = null;
    }

    return BannerMessage(
      message: message,
      action: action,
      variant: BannerVariant.accent,
      onDismiss: () {
        ref
            .read(deleteAccountControllerProvider.notifier)
            .updateToken(state.token);
      },
    );
  }
}
