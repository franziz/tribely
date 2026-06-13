import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/state/sign_in_intent.dart';
import '../../../auth/presentation/widgets/sign_in_gate_sheet.dart';
import '../string_assets/profile_signed_out_copy.dart';

/// Signed-out empty state for [OwnProfilePage].
///
/// Shown when [SessionUnauthenticated] is the active session state. Presents
/// copy and a "Sign in" CTA that opens the sign-in gate sheet.
///
/// On successful sign-in the session flip auto-rebuilds the page into the
/// authed path — no explicit navigation is needed here.
///
/// NOTE: this widget is intentionally separate from the identically-named
/// widget in [my_events/presentation/widgets/] — they live in different
/// bounded contexts with different copy. Do NOT share.
class SignedOutEmptyState extends ConsumerWidget {
  const SignedOutEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_outline,
              size: 56,
              color: TribelyColors.paperInkSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              ProfileSignedOutCopy.headline,
              style: TribelyType.headline(TribelyColors.paperInkPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              ProfileSignedOutCopy.body,
              style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: ProfileSignedOutCopy.cta,
              onPressed: () => _onSignInTapped(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSignInTapped(BuildContext context) async {
    // Open the sign-in gate sheet. On success the session flip auto-rebuilds
    // this page into the authed path — no further action needed here.
    await showSignInGateSheet(context, intent: const SignInIntentCreateEvent());
    // context.mounted guard: no navigation action to take on success, but
    // guard the post-await frame in case the widget was disposed mid-flight.
    if (!context.mounted) return;
  }
}
