import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../string_assets/review_copy.dart';

/// Opaque placeholder rendered for [ReviewBlindMutualPending] visibility rows.
///
/// Shown when the viewer has submitted a review but the counterparty has not
/// yet — content is withheld until both parties submit or 14 days pass.
class BlindReviewPlaceholder extends StatelessWidget {
  const BlindReviewPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: inkSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ReviewCopy.mutualWindowPending,
              style: TribelyType.bodyM(inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
