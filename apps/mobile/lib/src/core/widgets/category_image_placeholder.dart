import 'package:flutter/material.dart';

import '../../features/events/domain/entities/event_category.dart';
import 'category_visuals.dart';

/// Category-branded image placeholder.
///
/// Renders a solid category-color background with the centred category icon.
/// Used in two render sites:
///   1. The create-event wizard cover-photo step — "no photo selected" state
///      (Brief 4's render site swap).
///   2. Event cards / hero — image-load failure fallback (Brief 4).
///
/// Both render sites use this single widget so the placeholder appearance
/// stays consistent. The icon is sized relative to the widget's constraints
/// via [LayoutBuilder] — no hardcoded icon size.
///
/// Relocated from `events/presentation/widgets/` to `core/widgets/` in
/// TRI-49 Brief 4. The `core/widgets/ → events/domain` import is sanctioned —
/// precedent is `requester_profile_sheet.dart → users/domain/entities/`.
class CategoryImagePlaceholder extends StatelessWidget {
  const CategoryImagePlaceholder({required this.category, super.key});

  final EventCategory category;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale icon to ~20% of the shorter axis so it looks proportional
        // in both the card thumbnail and the full-width wizard preview.
        final iconSize = constraints.maxHeight.isFinite
            ? constraints.maxHeight * 0.2
            : 40.0;

        return ColoredBox(
          color: categoryColor(category),
          child: Center(
            child: Icon(
              categoryIcon(category),
              color: Colors.white.withValues(alpha: 0.7),
              size: iconSize.clamp(24.0, 80.0),
            ),
          ),
        );
      },
    );
  }
}
