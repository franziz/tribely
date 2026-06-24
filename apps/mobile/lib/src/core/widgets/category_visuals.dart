import 'package:flutter/material.dart';

import '../../features/events/domain/entities/event_category.dart';

/// Shared category→color and category→icon look-ups.
///
/// Consumed by [CategoryImagePlaceholder] (cover-photo render sites) and
/// any widget that needs the canonical category color or icon. Relocated
/// from `events/presentation/` to `core/widgets/` in TRI-49 Brief 4 so
/// both the discover feed card and the event-detail hero can import without
/// a cross-feature `discover → events/presentation` boundary violation.
///
/// `core/widgets/ → events/domain` is sanctioned — precedent is
/// `requester_profile_sheet.dart → users/domain/entities/user_profile.dart`.

/// Returns the category-specific background color.
///
/// Used as the solid fill when no cover image is available (or fails to load).
Color categoryColor(EventCategory category) => switch (category) {
  EventCategory.drinks => const Color(0xFFD85730), // ember coral
  EventCategory.food => const Color(0xFF4A7C59), // moss green
  EventCategory.hike => const Color(0xFF1B3D3A), // teak teal
  EventCategory.museum => const Color(0xFF5C544A), // warm slate
  EventCategory.sports => const Color(0xFF2E6B8A), // ocean blue
  EventCategory.nightlife => const Color(0xFF3D1F4A), // deep plum
  EventCategory.other => const Color(0xFF7A6E60), // neutral warm
};

/// Returns the display icon for a given [EventCategory].
///
/// Matches the category icon set used across the feed card thumbnail,
/// the event-detail hero, and the create-event wizard placeholder.
IconData categoryIcon(EventCategory category) => switch (category) {
  EventCategory.drinks => Icons.local_bar_outlined,
  EventCategory.food => Icons.restaurant_outlined,
  EventCategory.hike => Icons.terrain_outlined,
  EventCategory.museum => Icons.museum_outlined,
  EventCategory.sports => Icons.sports_soccer_outlined,
  EventCategory.nightlife => Icons.nightlife_outlined,
  EventCategory.other => Icons.star_outline,
};
