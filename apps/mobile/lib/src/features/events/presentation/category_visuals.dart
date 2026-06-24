import 'package:flutter/material.dart';

import '../domain/entities/event_category.dart';

/// Shared category→color and category→icon look-ups.
///
/// Consumed by [EventCard]'s thumbnail section (discover) and
/// [CategoryImagePlaceholder] (cover-photo render sites). Extracted here so
/// both sites stay in sync without duplication.
///
/// The colour values match the `_categoryColor` private function in
/// `discover/presentation/widgets/event_card.dart`; that function remains in
/// place (it cannot import from `events/presentation/` without violating
/// bounded-context rules) and must be kept in sync if values change here.

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
/// Matches [kCategoryIcons] in `events/presentation/widgets/category_icons.dart`
/// for the icons that overlap; the card and hero use the same icon font codes.
IconData categoryIcon(EventCategory category) => switch (category) {
  EventCategory.drinks => Icons.local_bar_outlined,
  EventCategory.food => Icons.restaurant_outlined,
  EventCategory.hike => Icons.terrain_outlined,
  EventCategory.museum => Icons.museum_outlined,
  EventCategory.sports => Icons.sports_soccer_outlined,
  EventCategory.nightlife => Icons.nightlife_outlined,
  EventCategory.other => Icons.star_outline,
};
