import 'package:flutter/material.dart';

import '../../domain/entities/event_category.dart';

/// Canonical icon map for all [EventCategory] values.
///
/// Shared by [CategorySheet] (row leading icon) and [CategorySelectorField]
/// (trigger leading icon). Extracted here to avoid duplication.
const Map<EventCategory, IconData> kCategoryIcons = {
  EventCategory.drinks: Icons.local_bar_outlined,
  EventCategory.food: Icons.restaurant_outlined,
  EventCategory.hike: Icons.terrain,
  EventCategory.museum: Icons.account_balance_outlined,
  EventCategory.sports: Icons.sports_outlined,
  EventCategory.nightlife: Icons.nightlife,
  EventCategory.other: Icons.category_outlined,
};
