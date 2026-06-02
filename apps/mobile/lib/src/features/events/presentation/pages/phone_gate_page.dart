import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/auth_page_scaffold.dart';

/// Full-screen phone-verification gate shown when a phone-unverified user
/// attempts to enter the create-event wizard (`/events/new`).
///
/// - No providers read — [StatelessWidget] suffices.
/// - Primary CTA starts the phone verification wizard with a `redirectTo`
///   query param so the verify page can navigate back into the wizard on
///   success.
/// - "Not now" returns the user to the Discover tab (`/events`).
class PhoneGatePage extends StatelessWidget {
  const PhoneGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final primaryColor = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;

    return AuthPageScaffold(
      title: 'Before you host, one quick thing.',
      subtitle:
          'We ask all hosts to verify their phone number. It keeps the community safer for everyone — and it only takes about a minute.',
      backFallback: '/events',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: Semantics(
              label: 'Phone verification required',
              child: Icon(Icons.phone_outlined, size: 48, color: primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Verify my number',
            onPressed: () {
              final redirectTo = Uri.encodeQueryComponent('/events/new');
              unawaited(
                context.push('/auth/phone/entry?redirectTo=$redirectTo'),
              );
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => context.go('/events'),
              child: Text('Not now', style: TribelyType.bodyM(inkSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}
