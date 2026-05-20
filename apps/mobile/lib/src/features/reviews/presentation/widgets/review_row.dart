import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/entities/review.dart';

// Cross-feature import: ReportReviewSheet is owned by the `reports` feature.
// This is a deliberate one-widget reference specified in Brief 2B and does NOT
// constitute a sanctioned cross-feature exception in CLAUDE.md. Inline comment
// documents the reference per Brief 2B requirement.
import '../../../reports/presentation/widgets/report_review_sheet.dart';

/// Renders a single visible review row.
///
/// Used in both the profile review list (public) and the "Reviews I wrote"
/// page (author view). When [reportedUserId] and [reportedUserDisplayName] are
/// provided, tapping the three-dot overflow icon shows a popup menu with
/// "Report this review", which opens [ReportReviewSheet] as a modal bottom
/// sheet.
///
/// When neither is provided, [onOverflowTap] is called instead (backward
/// compat for callers that supply their own overflow logic).
class ReviewRow extends StatelessWidget {
  const ReviewRow({
    required this.review,
    this.onOverflowTap,
    this.reportedUserId,
    this.reportedUserDisplayName,
    this.showEditLink = false,
    this.onEditTap,
    super.key,
  });

  final Review review;

  /// Display name of the user who wrote this review. Used in the report flow's
  /// block opt-in sheet ("Block [name]?").
  ///
  /// When provided alongside [reportedUserId], tapping the overflow icon opens
  /// the report sheet directly. When omitted, [onOverflowTap] is called.
  final String? reportedUserDisplayName;

  /// User ID of the review author. Required together with
  /// [reportedUserDisplayName] to enable the inline report sheet.
  final String? reportedUserId;

  /// Fallback callback called when [reportedUserId] / [reportedUserDisplayName]
  /// are not provided. Host page is responsible for pushing the appropriate
  /// sheet (report, edit, etc.).
  final VoidCallback? onOverflowTap;

  /// When true, shows an "Edit ›" inline link (visible only within 24h).
  final bool showEditLink;

  /// Callback for the "Edit ›" link. Required when [showEditLink] is true.
  final VoidCallback? onEditTap;

  void _handleOverflowTap(BuildContext context) {
    final userId = reportedUserId;
    final displayName = reportedUserDisplayName;
    if (userId != null && displayName != null) {
      _showReportMenu(context, userId, displayName);
    } else {
      onOverflowTap?.call();
    }
  }

  void _showReportMenu(
    BuildContext context,
    String userId,
    String displayName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportReviewSheet(
        reviewId: review.id,
        reportedUserId: userId,
        reportedUserDisplayName: displayName,
      ),
    );
  }

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
                onTap: () => _handleOverflowTap(context),
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
