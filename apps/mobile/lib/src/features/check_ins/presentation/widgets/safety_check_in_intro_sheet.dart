import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../string_assets/check_in_copy.dart';

/// One-time intro sheet explaining the post-event check-in feature.
///
/// Shown the first time a user is about to see [SafetyCheckInSheet].
/// The calling layer ([CheckInsOverlay]) is responsible for:
///   1. Checking [IntroFlagStorage.hasSeen] BEFORE showing this sheet.
///   2. Calling [IntroFlagStorage.markSeen] AFTER this sheet is dismissed.
///
/// This widget is purely presentational — it drives [onDismiss] when "Got it"
/// is tapped and lets the caller decide on flag-writing and subsequent actions.
class SafetyCheckInIntroSheet extends StatelessWidget {
  const SafetyCheckInIntroSheet({required this.onDismiss, super.key});

  /// Called when the user taps "Got it". The caller should mark the intro as
  /// seen and then present the actual [SafetyCheckInSheet].
  final VoidCallback onDismiss;

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
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: dark
                      ? TribelyColors.nightBorderSubtle
                      : TribelyColors.paperBorderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(introSheetTitle, style: TribelyType.headline(ink)),
            const SizedBox(height: 12),
            Text(introSheetBody, style: TribelyType.bodyM(inkSecondary)),
            const SizedBox(height: 28),
            PrimaryButton(label: introSheetCta, onPressed: onDismiss),
          ],
        ),
      ),
    );
  }
}
