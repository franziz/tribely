import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/legal/legal_constants.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/verification_required_banner.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../providers/users_providers.dart';
import '../state/user_profile_state.dart';
import '../widgets/profile_body.dart';
import '../widgets/signed_out_empty_state.dart';

// Settings is the user's own account surface — lives in this feature per
// the brief spec. OwnProfilePage exposes the entry point as a gear-icon
// action in the AppBar.

// Verbatim designer copy — do not paraphrase (TRI-142 Brief D).
const _kSectionLabel = 'ACCOUNT';
const _kSignOutLabel = 'Sign out';
const _kDeleteAccountLabel = 'Delete account';

class OwnProfilePage extends ConsumerWidget {
  const OwnProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    final session = ref.watch(sessionControllerProvider);

    // Signed-out: render empty state. Keep AppBar chrome; hide gear action
    // (Settings routes to /settings which is auth-required — hiding avoids
    // a confusing dead-end). Banners gate on authed fields — suppress them.
    if (session is SessionUnauthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Profile', style: TribelyType.headline(ink)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          // Gear action hidden signed-out — no settings surface for anon users.
        ),
        body: const SignedOutEmptyState(),
      );
    }

    // Restoring: silent hold — blank body, no spinner flash for a near-instant
    // transient, AppBar chrome shared across all branches.
    if (session is SessionRestoring) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Profile', style: TribelyType.headline(ink)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: const SizedBox.shrink(),
      );
    }

    // Authenticated path — render the full profile body with banners and
    // the settings gear action.
    final state = ref.watch(myProfileControllerProvider);
    final phoneRevoked =
        session is SessionAuthenticated && session.phoneRevokedSinceLastSeen;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: TribelyType.headline(ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Contested-phone neutral banner — transient, dismissible.
          if (phoneRevoked)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: BannerMessage(
                variant: BannerVariant.neutral,
                message: kContestedPhoneBannerCopy,
                action: BannerAction(
                  label: 'Verify now →',
                  onTap: () => context.go('/auth/phone/entry'),
                ),
                onDismiss: () => ref
                    .read(sessionControllerProvider.notifier)
                    .dismissPhoneRevokedBanner(),
              ),
            ),
          // Email verification banner (email above phone per spec).
          const VerificationRequiredBanner(type: VerificationType.email),
          // Phone verification banner.
          const VerificationRequiredBanner(type: VerificationType.phone),
          Expanded(
            child: switch (state) {
              UserProfileLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              UserProfileLoaded(:final profile) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: ProfileBody(profile: profile, isOwn: true)),
                  _AccountSection(
                    ink: ink,
                    inkSecondary: inkSecondary,
                    dark: dark,
                    onSignOut: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sign out of Tribely?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Sign out'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await ref
                            .read(sessionControllerProvider.notifier)
                            .signOut();
                      }
                    },
                    onDeleteAccount: () => context.push('/account/delete'),
                  ),
                ],
              ),
              UserProfileError(:final message) => _ErrorView(
                message: message,
                onRetry: () =>
                    ref.read(myProfileControllerProvider.notifier).retry(),
                inkSecondary: inkSecondary,
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Account section displayed below the profile body on [OwnProfilePage].
///
/// Contains two list rows — Sign out and Delete account — separated by a
/// hairline divider, under an "ACCOUNT" caption section label.
///
/// Design spec §Screen 1 (TRI-142):
///   - Sign out row: inkSecondary color, Icons.logout, chevron.
///   - Delete account row: paperAccent/nightAccent color, Icons.delete_forever, chevron.
///   - Each row: 56dp min height, 24dp horizontal padding, 12dp icon→label gap,
///     bodyM label weight.
///   - Section divider: caption weight, centered, with hairline rules.
class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.ink,
    required this.inkSecondary,
    required this.dark,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final Color ink;
  final Color inkSecondary;
  final bool dark;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final accentColor = dark
        ? TribelyColors.nightAccent
        : TribelyColors.paperAccent;
    final dividerColor = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section divider — "ACCOUNT" caption with hairline rules.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Divider(color: dividerColor, thickness: 0.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _kSectionLabel,
                  style: TribelyType.caption(inkSecondary),
                ),
              ),
              Expanded(child: Divider(color: dividerColor, thickness: 0.5)),
            ],
          ),
        ),

        // Sign out row.
        InkWell(
          onTap: onSignOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  Icon(Icons.logout, color: inkSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _kSignOutLabel,
                      style: TribelyType.bodyM(inkSecondary),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: inkSecondary, size: 20),
                ],
              ),
            ),
          ),
        ),

        // Hairline divider between rows.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Divider(color: dividerColor, thickness: 0.5, height: 0),
        ),

        // Delete account row.
        InkWell(
          onTap: onDeleteAccount,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: accentColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _kDeleteAccountLabel,
                      style: TribelyType.bodyM(accentColor),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: inkSecondary, size: 20),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.inkSecondary,
  });

  final String message;
  final VoidCallback onRetry;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              style: TribelyType.bodyM(inkSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
