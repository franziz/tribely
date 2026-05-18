import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/state/auth_state.dart';
import 'banner_message.dart';

/// Which verification the banner is prompting for.
enum VerificationType { email, phone }

/// A soft-accent banner that prompts the user to verify their email or phone.
/// Renders empty ([SizedBox.shrink]) when:
///   - The session is not authenticated.
///   - The relevant verification is already satisfied.
///
/// Mount multiple banners to stack them (email above phone) when both are
/// unverified — the widget itself handles one type per instance.
///
/// Usage:
/// ```dart
/// Column(children: [
///   VerificationRequiredBanner(type: VerificationType.email),
///   VerificationRequiredBanner(type: VerificationType.phone),
/// ])
/// ```
class VerificationRequiredBanner extends ConsumerWidget {
  const VerificationRequiredBanner({super.key, required this.type});

  final VerificationType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) return const SizedBox.shrink();

    final user = session.session.user;
    final shouldShow = switch (type) {
      VerificationType.email => !user.isEmailVerified,
      VerificationType.phone => !user.isPhoneVerified,
    };

    if (!shouldShow) return const SizedBox.shrink();

    final message = switch (type) {
      VerificationType.email =>
        'Verify your email to unlock joining and creating events.',
      VerificationType.phone =>
        'Verify your phone to unlock joining and creating events.',
    };

    final route = switch (type) {
      VerificationType.email => '/verify-email',
      VerificationType.phone => '/auth/phone/entry',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: BannerMessage(
        message: message,
        action: BannerAction(
          label: 'Verify now →',
          onTap: () => context.go(route),
        ),
      ),
    );
  }
}
