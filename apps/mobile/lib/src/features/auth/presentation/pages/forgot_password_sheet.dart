import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';

/// MVP placeholder. The entry point exists so users find it; the flow
/// itself is "email support@tribely.app". When the real reset flow is
/// implemented, this sheet becomes the form — same entry point, no
/// relearning.
Future<void> showForgotPasswordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _ForgotPasswordSheet(),
  );
}

class _ForgotPasswordSheet extends StatelessWidget {
  const _ForgotPasswordSheet();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 24),
            Text(
              'Password reset is coming soon.',
              style: TribelyType.headline(ink),
            ),
            const SizedBox(height: 12),
            Text(
              'Email support@tribely.app to recover your account, and we’ll get you back in.',
              style: TribelyType.bodyL(inkSecondary),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
