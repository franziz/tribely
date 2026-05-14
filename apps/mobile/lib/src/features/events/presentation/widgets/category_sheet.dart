import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/entities/event_category.dart';

/// Icon for each [EventCategory] row in [CategorySheet].
const Map<EventCategory, IconData> _kCategoryIcons = {
  EventCategory.drinks: Icons.local_bar_outlined,
  EventCategory.food: Icons.restaurant_outlined,
  EventCategory.hike: Icons.terrain,
  EventCategory.museum: Icons.account_balance_outlined,
  EventCategory.sports: Icons.sports_outlined,
  EventCategory.nightlife: Icons.nightlife,
  EventCategory.other: Icons.category_outlined,
};

/// Pattern A single-select bottom-sheet content.
///
/// Renders the seven [EventCategory] rows in enum declaration order.
/// Selection is immediate: tapping a row announces the choice via
/// [SemanticsService.announce] and calls [Navigator.pop] with the tapped
/// category. No Confirm button — tap-to-dismiss is the specified interaction.
///
/// The sheet does NOT hold any selected-row state; [initial] is used purely to
/// render the pre-selected checkmark on open.
///
/// Usage (inside [CategorySelectorField]):
/// ```dart
/// final result = await showModalBottomSheet<EventCategory?>(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   isDismissible: true,
///   enableDrag: true,
///   builder: (_) => CategorySheet(initial: value),
/// );
/// ```
class CategorySheet extends StatelessWidget {
  const CategorySheet({required this.initial, super.key});

  final EventCategory? initial;

  @override
  Widget build(BuildContext context) {
    final categories = EventCategory.values;

    return Semantics(
      label: 'Choose a category',
      explicitChildNodes: true,
      child: Container(
        decoration: const BoxDecoration(
          color: TribelyColors.paperSurfaceHigh,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle: 32×4dp centred — matches ConfirmJoinSheet lines 105–115.
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: TribelyColors.paperBorderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Headline.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a category',
                  style: TribelyType.headline(TribelyColors.paperInkPrimary),
                ),
              ),
            ),
            // Header divider.
            const Divider(
              height: 1,
              thickness: 1,
              color: TribelyColors.paperBorderSubtle,
            ),
            // Category rows.
            for (var i = 0; i < categories.length; i++) ...[
              _CategoryRow(
                category: categories[i],
                isSelected: categories[i] == initial,
              ),
              // 1dp divider between rows; none after the last.
              if (i < categories.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: TribelyColors.paperBorderSubtle,
                ),
            ],
            // Safe-area bottom padding — matches ConfirmJoinSheet line 199.
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
          ],
        ),
      ),
    );
  }
}

/// A single tappable category row inside [CategorySheet].
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.isSelected,
  });

  final EventCategory category;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected
        ? TribelyColors.paperPrimary
        : TribelyColors.paperInkSecondary;
    final labelColor = isSelected
        ? TribelyColors.paperInkPrimary
        : TribelyColors.paperInkSecondary;

    final semanticsLabel = isSelected
        ? '${category.displayName}, selected'
        : category.displayName;

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkWell(
        onTap: () {
          SemanticsService.announce(
            '${category.displayName} selected',
            TextDirection.ltr,
          );
          Navigator.pop(context, category);
        },
        splashColor: TribelyColors.paperPrimary.withAlpha(20),
        highlightColor: TribelyColors.paperPrimary.withAlpha(10),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(
                  _kCategoryIcons[category],
                  size: 22,
                  color: iconColor,
                ),
                const SizedBox(width: 16),
                Text(
                  category.displayName,
                  style: TribelyType.bodyM(labelColor),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(
                    Icons.check,
                    size: 20,
                    color: TribelyColors.paperPrimary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
