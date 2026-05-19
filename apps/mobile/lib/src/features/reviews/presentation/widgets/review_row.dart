import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/entities/review.dart';

/// Renders a single visible review row.
///
/// Used in both the profile review list (public) and the "Reviews I wrote"
/// page (author view). The caller controls the [overflowMenuCallback] — for
/// public-profile views this should open a report sheet; for the author's own
/// list it may offer edit/delete actions.
///
/// The [onOverflowTap] callback fires when the three-dot menu is tapped. The
/// actual sheet content is provided by the caller so this widget stays
/// context-agnostic.
///
/// Report sheet integration (Brief 2B):
/// // TODO: import ReportReviewSheet from reports/ when Brief 2B lands
class ReviewRow extends StatelessWidget {
  const ReviewRow({
    required this.review,
    required this.onOverflowTap,
    this.showEditLink = false,
    this.onEditTap,
    super.key,
  });

  final Review review;

  /// Called when the three-dot overflow icon is tapped. Host page is
  /// responsible for pushing the appropriate sheet (report, edit, etc.).
  final VoidCallback onOverflowTap;

  /// When true, shows an "Edit ›" inline link (visible only within 24h).
  final bool showEditLink;

  /// Callback for the "Edit ›" link. Required when [showEditLink] is true.
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Star row
              _StarRow(rating: review.rating, color: primary),
              const Spacer(),
              // Three-dot overflow
              GestureDetector(
                onTap: onOverflowTap,
                child: Icon(Icons.more_horiz, size: 20, color: inkSecondary),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: TribelyType.bodyM(ink),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                DateFormat('d MMM yyyy').format(review.createdAt),
                style: TribelyType.caption(inkSecondary),
              ),
              if (showEditLink && onEditTap != null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: onEditTap,
                  child: Text('Edit ›', style: TribelyType.caption(primary)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.color});

  final int rating;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: 16,
          color: color,
        );
      }),
    );
  }
}
