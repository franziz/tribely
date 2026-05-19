import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/value_objects/selfie_failure_category.dart';
import '../string_assets/verification_failure_copy.dart';

/// Auto-presented modal bottom sheet shown once on the pending → failed
/// transition.
///
/// Presenting rules:
///   - Present from the ROOT navigator context (NOT from a tab branch) so the
///     sheet survives [StatefulShellRoute.indexedStack] tab switches.
///   - Present once per (userId, attemptCount) key — tracked by
///     [selfieRejectionListenerProvider].
///   - Drag-dismissible ([isDismissible] = true on the [showModalBottomSheet]
///     call site).
///
/// [onViewDetails] routes to /verification/failure when the user taps the CTA.
class VerificationRejectedSheet extends StatelessWidget {
  const VerificationRejectedSheet({
    required this.category,
    required this.attemptCount,
    required this.isLocked,
    required this.onViewDetails,
    super.key,
  });

  final SelfieFailureCategory? category;
  final int attemptCount;

  /// True when the user is at attempt 3 (locked state).
  final bool isLocked;

  /// Called when the user taps the primary CTA ("See what to do next" /
  /// "Contact support" — whichever is appropriate for the state). Routes to
  /// /verification/failure.
  final VoidCallback onViewDetails;

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
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

    final title = verificationFailureTitle(category);
    final body = isLocked
        ? kVerificationLockedBody
        : verificationFailureBody(category);

    return Semantics(
      liveRegion: true,
      label: "Your selfie didn't pass review. Open notifications for details.",
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // isScrollControlled should be true at the call site so the sheet can
        // occupy up to the full screen height when content is tall.
        child: SingleChildScrollView(
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
              // Icon + title row.
              Row(
                children: [
                  Icon(
                    isLocked
                        ? Icons.lock_outline_rounded
                        : Icons.warning_amber_rounded,
                    color: accent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: TribelyType.headline(ink)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(body, style: TribelyType.bodyM(inkSecondary)),
              const SizedBox(height: 24),
              PrimaryButton(
                label: isLocked ? 'Contact support' : 'See what to do next',
                onPressed: () {
                  Navigator.of(context).pop();
                  onViewDetails();
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Dismiss', style: TribelyType.button(inkSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
