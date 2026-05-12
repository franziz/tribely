import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../events/domain/entities/event_category.dart';

/// Custom pin widget for a single event marker on the Discover map.
///
/// Spec §D Map pins:
///   - 40dp circle, [TribelyColors.paperPrimary] fill.
///   - White category icon (20dp) centred inside the circle.
///
/// The widget is intentionally stateless and has no dependency on flutter_map
/// internals so it can be unit-tested in isolation and reused by the cluster
/// builder as the base visual shape.
class EventMapMarker extends StatelessWidget {
  const EventMapMarker({required this.category, super.key});

  final EventCategory category;

  /// Diameter used for single-event pins (spec §D).
  static const double kSingleDiameter = 40.0;

  @override
  Widget build(BuildContext context) {
    return _PinCircle(
      diameter: kSingleDiameter,
      child: Icon(_iconForCategory(category), color: Colors.white, size: 20),
    );
  }

  /// Maps an [EventCategory] to a representative Material icon.
  ///
  /// The spec requires a "category-specific icon" — using the closest
  /// semantic match from the Material icon set for each category.
  static IconData _iconForCategory(EventCategory category) {
    return switch (category) {
      EventCategory.drinks => Icons.local_bar_outlined,
      EventCategory.food => Icons.restaurant_outlined,
      EventCategory.hike => Icons.terrain_outlined,
      EventCategory.museum => Icons.museum_outlined,
      EventCategory.sports => Icons.sports_outlined,
      EventCategory.nightlife => Icons.nightlife_outlined,
      EventCategory.other => Icons.event_outlined,
    };
  }
}

// ---------------------------------------------------------------------------
// Cluster pin widget
// ---------------------------------------------------------------------------

/// Cluster pin used by [MarkerClusterLayerWidget].
///
/// Spec §D Map pins — cluster:
///   - Same [TribelyColors.paperPrimary] fill, white event-count label
///     ([TribelyType.caption], white).
///   - White 2dp stroke border.
///   - Size varies with cluster population:
///       2–5  events → 40dp
///       6–15 events → 48dp
///       16+  events → 56dp
class EventClusterMarker extends StatelessWidget {
  const EventClusterMarker({required this.count, super.key});

  final int count;

  /// Returns the cluster diameter per the spec §D sizing table.
  static double diameterForCount(int count) {
    if (count >= 16) return 56.0;
    if (count >= 6) return 48.0;
    return 40.0;
  }

  @override
  Widget build(BuildContext context) {
    final diameter = diameterForCount(count);
    return _PinCircle(
      diameter: diameter,
      borderWidth: 2.0,
      child: Text('$count', style: TribelyType.caption(Colors.white)),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared filled circle shell
// ---------------------------------------------------------------------------

/// Internal building block: filled [TribelyColors.paperPrimary] circle with an
/// optional white border and a centred [child].
class _PinCircle extends StatelessWidget {
  const _PinCircle({
    required this.diameter,
    required this.child,
    this.borderWidth = 0.0,
  });

  final double diameter;
  final Widget child;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: TribelyColors.paperPrimary,
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(color: Colors.white, width: borderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}
