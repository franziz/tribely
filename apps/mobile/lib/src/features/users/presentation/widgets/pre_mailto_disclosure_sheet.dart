import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../string_assets/verification_appeal_disclosure.dart';

/// PDPA s14 consent sheet displayed BEFORE the device mail client opens.
///
/// Copy is verbatim from the canonical SoT:
///   docs/policies/verification-appeal-disclosure.in-app-excerpt.md
///
/// Present with [showModalBottomSheet] from the ROOT navigator context.
/// [onConfirm] is called when the user taps "Open email app".
/// The sheet dismisses itself on both confirm and cancel.
class PreMailtoDisclosureSheet extends StatelessWidget {
  const PreMailtoDisclosureSheet({required this.onConfirm, super.key});

  /// Called when the user consents and taps "Open email app".
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle.
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
          Text(
            kDisclosureSheetTitle,
            style: TribelyType.headline(ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(kDisclosureSheetBody, style: TribelyType.bodyM(inkSecondary)),
          const SizedBox(height: 24),
          PrimaryButton(
            label: kDisclosurePrimaryAction,
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: kDisclosureSecondaryAction,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
