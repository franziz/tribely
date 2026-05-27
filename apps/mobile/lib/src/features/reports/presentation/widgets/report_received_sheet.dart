import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../string_assets/report_copy.dart';

/// ReportReceivedSheet — terminal confirmation surface for the report flow.
///
/// Persistent (drag-to-dismiss) bottom sheet shown immediately after a
/// successful report submission. Displays the SLA inline (NOT behind a
/// tap) per TRI-164 acceptance criteria, and links to the Help Centre
/// report-FAQ article.
///
/// Triggered by report_review_sheet.dart#_handleSuccess. On the secondary
/// link tap, the sheet is dismissed first, then the article is pushed
/// onto the navigation stack — so back-nav from the article returns to
/// the underlying context (event detail / profile / chat), not to a
/// re-opened sheet.
///
/// Numerical coupling: the "72 hours" / "7 days" figures in this sheet's
/// copy (in report_copy.dart) MUST stay aligned with help_centre_copy.dart
/// and docs/runbooks/moderation-cli.md §2.
class ReportReceivedSheet extends StatelessWidget {
  final VoidCallback onLearnMore;
  const ReportReceivedSheet({super.key, required this.onLearnMore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final success = dark
        ? TribelyColors.nightSuccess
        : TribelyColors.paperSuccess;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle 32x4
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: inkSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            ExcludeSemantics(
              child: Icon(Icons.check_circle_outline, size: 40, color: success),
            ),
            const SizedBox(height: 16),
            Text(
              ReportCopy.sheetHeadline,
              style: theme.textTheme.titleLarge?.copyWith(
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ReportCopy.sheetBodyParagraph1,
              style: theme.textTheme.bodyLarge?.copyWith(color: inkSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              ReportCopy.sheetBodyParagraph2Sla,
              style: theme.textTheme.bodyLarge?.copyWith(color: inkSecondary),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            PrimaryButton(
              label: ReportCopy.sheetPrimaryCta,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: onLearnMore,
                child: const Text(ReportCopy.sheetSecondaryLink),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
