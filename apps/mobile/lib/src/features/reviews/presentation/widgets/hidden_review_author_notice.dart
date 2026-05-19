import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../string_assets/review_copy.dart';

/// Notice rendered for [ReviewHidden] rows in the author's own review list.
///
/// Only shown to the author (authorViewOnly: true); never displayed on
/// public-facing profile pages.
class HiddenReviewAuthorNotice extends StatelessWidget {
  const HiddenReviewAuthorNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final accentSoft = dark
        ? TribelyColors.nightAccentSoft
        : TribelyColors.paperAccentSoft;
    final inkPrimary = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ReviewCopy.hiddenReviewAuthorNotice,
              style: TribelyType.bodyM(inkPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
