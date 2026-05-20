import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/ink_mark.dart';
import '../../../../core/widgets/primary_button.dart';

/// Terminal screen shown after successful account deletion.
///
/// AC4: navigator stack is replaced via context.go('/account-deleted') — no
///      back-nav into the authenticated app is possible.
/// AC5: "Back to sign in" CTA routes to /welcome (the unauthenticated entry
///      point), completing the sign-out → unauthenticated entry flow.
///
/// PopScope(canPop: false) intercepts Android physical back and routes to
/// /welcome, mirroring the CTA — back cannot re-enter the authenticated app.
class AccountDeletedPage extends ConsumerWidget {
  const AccountDeletedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return Semantics(
      liveRegion: true,
      label: 'Account deleted. Your account has been deleted.',
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/welcome');
        },
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Vertical upward bias — prevents the logo from feeling
                    // pinned to the exact viewport center on tall phones.
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: InkMark(size: 48, color: inkPrimary),
                    ),

                    const SizedBox(height: 48),

                    Text(
                      'Your account has been deleted.',
                      style: TribelyType.headline(inkPrimary),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Your data will be removed within 30 days, in line with our Privacy Policy.',
                      style: TribelyType.bodyM(inkSecondary),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    PrimaryButton(
                      label: 'Back to sign in',
                      onPressed: () => context.go('/welcome'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
