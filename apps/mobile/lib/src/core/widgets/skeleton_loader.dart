import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Base color for shimmer skeleton shapes (light mode).
///
/// `paperBorderSubtle` from the Tribely palette is intentionally warm-grey —
/// using it keeps skeletons on-brand without importing [TribelyColors] (which
/// would pull in the full color module for a utility widget). If the palette
/// ever gains explicit `skeletonBase` / `skeletonHighlight` tokens, replace
/// these consts and delete this comment.
const Color _kSkeletonBase = Color(0xFFE8DFD0); // paperBorderSubtle

/// Highlight color for the shimmer sweep — just above the base.
const Color _kSkeletonHighlight = Color(0xFFFAF6EF); // paperSurface

/// Duration of one full shimmer sweep, per §H (1500 ms).
const Duration _kShimmerPeriod = Duration(milliseconds: 1500);

/// A single shimmering rectangle — the atomic building block for all skeleton
/// loading states in the app.
///
/// Use [SkeletonLoader] when you need a shaped placeholder for arbitrary
/// content (e.g., an avatar circle, a short text line). Combine multiples to
/// compose a silhouette, or use [SkeletonEventCard] which does that for the
/// standard list-card shape.
///
/// Parameters:
/// - [width] — explicit width in logical pixels. Pass [double.infinity] to
///   fill available horizontal space.
/// - [height] — explicit height in logical pixels.
/// - [borderRadius] — corner radius applied to the rectangle; defaults to 8dp
///   (§H visual rhythm).
///
/// Technical notes:
/// - Uses [Shimmer.fromColors] from the `shimmer` package — do NOT replace
///   this with a manual [AnimationController] implementation (brief A3 spec).
/// - No dark-mode variant in v1 (brief A3 non-goal); extend when dark-mode
///   palette tokens are added.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _kSkeletonBase,
      highlightColor: _kSkeletonHighlight,
      period: _kShimmerPeriod,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _kSkeletonBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton silhouette for an event list-card — matches the ~200dp card
/// height and internal layout described in §H ("Initial load — list"):
///
/// ```
/// ┌──────────────────────────────────────┐
/// │  image block (full-width, 120dp)     │
/// ├──────────────────────────────────────┤
/// │  title line  (70% width, 16dp)   12dp│
/// │  subtitle    (50% width, 12dp)    8dp│
/// │  meta row    (90% width, 12dp)   12dp│
/// └──────────────────────────────────────┘
/// ```
///
/// All rectangles share a single [Shimmer.fromColors] ancestor so the sweep
/// highlight travels across the entire card in one pass (rather than each
/// piece having its own independent shimmer cycle).
///
/// Intended usage: render 3 of these stacked with 12dp gaps for the initial
/// list-load state per §H.
class SkeletonEventCard extends StatelessWidget {
  const SkeletonEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _kSkeletonBase,
      highlightColor: _kSkeletonHighlight,
      period: _kShimmerPeriod,
      child: Container(
        // Clip the card to rounded corners so the internal rectangles respect
        // the card boundary without each needing its own border-radius.
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image block — full-width, 120dp tall.
            const _ShimmerRect(
              width: double.infinity,
              height: 120,
              borderRadius: 0, // clipped by parent Card
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title text line — 70% of card width.
                      _ShimmerRect(
                        width: cardWidth * 0.70,
                        height: 16,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 8),
                      // Subtitle — 50%.
                      _ShimmerRect(
                        width: cardWidth * 0.50,
                        height: 12,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 12),
                      // Meta row — 90%.
                      _ShimmerRect(
                        width: cardWidth * 0.90,
                        height: 12,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal utility rectangle used inside [SkeletonEventCard].
///
/// Not exported — callers outside this file should use [SkeletonLoader] for
/// individual rectangles and [SkeletonEventCard] for the composed silhouette.
class _ShimmerRect extends StatelessWidget {
  const _ShimmerRect({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _kSkeletonBase,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
