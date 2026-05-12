import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/entities/event_category.dart';

/// Formatter matching §8 datetime spec: "Sat, 14 Jun · 7:00 PM SGT"
final _kDateFormat = DateFormat('EEE, d MMM · h:mm a');

/// Shadow definition per §C: 0 2dp 8dp #1A1714 at 6%.
const List<BoxShadow> _kCardShadow = [
  BoxShadow(
    color: Color(0x0F1A1714), // 6% of #1A1714
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];

/// Returns the category-color fallback background color for the thumbnail area.
/// Used when no image URL is available.
Color _categoryColor(EventCategory category) => switch (category) {
  EventCategory.drinks => const Color(0xFFD85730), // ember coral
  EventCategory.food => const Color(0xFF4A7C59), // moss green
  EventCategory.hike => const Color(0xFF1B3D3A), // teak teal
  EventCategory.museum => const Color(0xFF5C544A), // warm slate
  EventCategory.sports => const Color(0xFF2E6B8A), // ocean blue
  EventCategory.nightlife => const Color(0xFF3D1F4A), // deep plum
  EventCategory.other => const Color(0xFF7A6E60), // neutral warm
};

/// Returns the display icon for a given [EventCategory].
IconData _categoryIcon(EventCategory category) => switch (category) {
  EventCategory.drinks => Icons.local_bar_outlined,
  EventCategory.food => Icons.restaurant_outlined,
  EventCategory.hike => Icons.terrain_outlined,
  EventCategory.museum => Icons.museum_outlined,
  EventCategory.sports => Icons.sports_soccer_outlined,
  EventCategory.nightlife => Icons.nightlife_outlined,
  EventCategory.other => Icons.star_outline,
};

/// Full-width event card for the Discover list feed.
///
/// Renders per §C:
/// - 16:9 thumbnail with category-color fallback, category badge bottom-left.
/// - Title (2-line max), datetime, venue, capacity badge.
/// - Tap routes to `/events/:id`.
///
/// V1 trims: no host name, no goingCount. Capacity line is omitted entirely
/// when [Event.capacity] is zero (should not occur per API contract, but
/// guarded defensively).
class EventCard extends StatelessWidget {
  const EventCard({required this.event, super.key});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: TribelyColors.paperSurfaceHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.go('/events/${event.id}'),
          borderRadius: BorderRadius.circular(16),
          splashColor: TribelyColors.paperInkPrimary.withValues(alpha: 0.06),
          highlightColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _kCardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThumbnailSection(event: event),
                  _ContentSection(event: event),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thumbnail section (16:9 with category badge)
// ---------------------------------------------------------------------------

class _ThumbnailSection extends StatelessWidget {
  const _ThumbnailSection({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: category-color fallback (no remote images in v1).
          Container(color: _categoryColor(event.category)),
          // Category badge — bottom-left of image per §C.
          Positioned(
            left: 12,
            bottom: 10,
            child: _CategoryBadge(category: event.category),
          ),
        ],
      ),
    );
  }
}

/// Pill badge overlaid on the thumbnail: category icon + display name.
/// Surface: paperSurface at 80% opacity, 8dp horizontal / 4dp vertical pad.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final EventCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TribelyColors.paperSurface.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _categoryIcon(category),
            size: 20,
            color: TribelyColors.paperInkPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            category.displayName,
            style: TribelyType.caption(TribelyColors.paperInkPrimary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content section (title + meta rows)
// ---------------------------------------------------------------------------

class _ContentSection extends StatelessWidget {
  const _ContentSection({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${_kDateFormat.format(event.startsAt)} SGT';
    final isFull = event.capacity <= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title — bodyL semibold, max 2 lines.
          Text(
            event.title,
            style: TribelyType.bodyL(TribelyColors.paperInkPrimary).copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Meta row 1 — datetime.
          Text(
            dateLabel,
            style: TribelyType.caption(TribelyColors.paperInkSecondary),
          ),
          const SizedBox(height: 4),
          // Meta row 2 — venue + capacity badge.
          Row(
            children: [
              Expanded(
                child: Text(
                  event.venue.address,
                  style: TribelyType.caption(TribelyColors.paperInkSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (event.capacity > 0) ...[
                const SizedBox(width: 8),
                _CapacityBadge(capacity: event.capacity, isFull: isFull),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Capacity badge: "{n} spots" or "Full" in paperAccent when all spots filled.
class _CapacityBadge extends StatelessWidget {
  const _CapacityBadge({required this.capacity, required this.isFull});

  final int capacity;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    final label = isFull ? 'Full' : '$capacity spots';
    final color = isFull
        ? TribelyColors.paperAccent
        : TribelyColors.paperInkSecondary;

    return Text(label, style: TribelyType.caption(color));
  }
}
