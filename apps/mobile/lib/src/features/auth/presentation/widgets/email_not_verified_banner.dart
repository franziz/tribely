import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/banner_message.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

/// Renders a soft banner whenever the authenticated user hasn't verified
/// their email yet. Dismissing it is intentionally not allowed — the
/// "Verify now" action takes the user to the dedicated verify-email page.
class EmailNotVerifiedBanner extends ConsumerWidget {
  const EmailNotVerifiedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) return const SizedBox.shrink();
    if (session.session.user.isEmailVerified) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: BannerMessage(
        message: 'Verify your email to unlock joining and creating events.',
        action: BannerAction(
          label: 'Verify now →',
          onTap: () => context.go('/verify-email'),
        ),
      ),
    );
  }
}
