import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/entities/profile_review_aggregate.dart';
import '../string_assets/review_copy.dart';

/// Profile section widget displaying the reviews aggregate.
///
/// Accepts a [ProfileReviewAggregate] and renders one of three states:
///   - Empty: "No reviews yet" in italicCaption style.
///   - Populated: star+average+count header, up to 3 recent comments,
///     "See all" link.
///   - Mutual-window-pending: opaque "Reviews pending" block (per designer spec).
///
/// The mutual-window state is signaled by [mutualWindowPending] being true.
/// Hidden-row filtering happens server-side; this widget renders whatever
/// is passed in [aggregate].
class ProfileReviewsAggregate extends StatelessWidget {
  const ProfileReviewsAggregate({
    required this.aggregate,
    required this.onSeeAll,
    this.mutualWindowPending = false,
    super.key,
  });

  final ProfileReviewAggregate aggregate;
  final VoidCallback onSeeAll;

  /// When true, the mutual-window opaque placeholder is rendered instead of
  /// real content. The viewer has submitted a review but the other party
  /// has not yet.
  final bool mutualWindowPending;

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
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews', style: TribelyType.headline(ink)),
        const SizedBox(height: 12),
        if (mutualWindowPending)
          _MutualWindowPending(
            surface: surface,
            border: border,
            inkSecondary: inkSecondary,
          )
        else if (aggregate.isEmpty)
          _EmptyState(inkSecondary: inkSecondary)
        else
          _PopulatedState(
            aggregate: aggregate,
            onSeeAll: onSeeAll,
            ink: ink,
            inkSecondary: inkSecondary,
            primary: primary,
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.inkSecondary});
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return Text(
      ReviewCopy.noReviewsYet,
      style: TribelyType.italicCaption(inkSecondary),
    );
  }
}

class _MutualWindowPending extends StatelessWidget {
  const _MutualWindowPending({
    required this.surface,
    required this.border,
    required this.inkSecondary,
  });
  final Color surface;
  final Color border;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, size: 18, color: inkSecondary),
          const SizedBox(width: 8),
          Text(
            ReviewCopy.reviewsPending,
            style: TribelyType.bodyM(inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _PopulatedState extends StatelessWidget {
  const _PopulatedState({
    required this.aggregate,
    required this.onSeeAll,
    required this.ink,
    required this.inkSecondary,
    required this.primary,
  });

  final ProfileReviewAggregate aggregate;
  final VoidCallback onSeeAll;
  final Color ink;
  final Color inkSecondary;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Average rating header
        Row(
          children: [
            Icon(Icons.star, size: 20, color: primary),
            const SizedBox(width: 4),
            Text(
              aggregate.averageRating != null
                  ? aggregate.averageRating!.toStringAsFixed(1)
                  : '—',
              style: TribelyType.bodyL(ink),
            ),
            const SizedBox(width: 6),
            Text(
              '(${aggregate.reviewCount})',
              style: TribelyType.bodyM(inkSecondary),
            ),
          ],
        ),
        if (aggregate.recentVisibleComments.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...aggregate.recentVisibleComments.map(
            (comment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CommentExcerpt(
                comment: comment.excerpt,
                rater: comment.raterDisplayName,
                ink: ink,
                inkSecondary: inkSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            ReviewCopy.seeAll,
            style: TribelyType.caption(
              primary,
            ).copyWith(decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }
}

class _CommentExcerpt extends StatelessWidget {
  const _CommentExcerpt({
    required this.comment,
    required this.rater,
    required this.ink,
    required this.inkSecondary,
  });
  final String comment;
  final String rater;
  final Color ink;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '"$comment"',
          style: TribelyType.bodyM(ink),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text('— $rater', style: TribelyType.caption(inkSecondary)),
      ],
    );
  }
}
