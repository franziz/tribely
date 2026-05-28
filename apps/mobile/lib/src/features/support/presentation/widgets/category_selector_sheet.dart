import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/entities/support_ticket_draft.dart';
import '../string_assets/support_copy.dart';

/// Single-select bottom-sheet for choosing a [SupportCategory].
///
/// Renders the six [SupportCategory] rows in canonical order (matching the
/// product spec and [supportCategoryDisplayName] ordering). Selection is
/// immediate: tapping a row announces the choice via
/// [SemanticsService.sendAnnouncement] and calls [Navigator.pop] with the
/// selected category. No confirm button — tap-to-dismiss is the spec'd
/// interaction (mirrors events/CategorySheet pattern from TRI-61).
///
/// [initial] is used only to render the pre-selected checkmark on open; the
/// sheet holds no mutable state.
///
/// Usage (from [SupportContactPage]):
/// ```dart
/// final result = await showModalBottomSheet<SupportCategory?>(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   isDismissible: true,
///   enableDrag: true,
///   builder: (_) => CategorySelectorSheet(initial: _selectedCategory),
/// );
/// if (result != null) setState(() => _selectedCategory = result);
/// ```
class CategorySelectorSheet extends StatelessWidget {
  const CategorySelectorSheet({required this.initial, super.key});

  final SupportCategory? initial;

  @override
  Widget build(BuildContext context) {
    final categories = SupportCategory.values;

    return Semantics(
      label: supportCategorySheetSemanticLabel,
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
            // Drag handle — 32×4dp centred, matches CategorySheet from events.
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
            // Sheet headline.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  supportCategorySheetTitle,
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
              if (i < categories.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: TribelyColors.paperBorderSubtle,
                ),
            ],
            // Safe-area bottom padding.
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
          ],
        ),
      ),
    );
  }
}

/// A single tappable category row inside [CategorySelectorSheet].
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.isSelected});

  final SupportCategory category;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final labelColor = isSelected
        ? TribelyColors.paperInkPrimary
        : TribelyColors.paperInkSecondary;

    final displayName = supportCategoryDisplayName(category);
    final semanticsLabel = isSelected ? '$displayName, selected' : displayName;

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkWell(
        onTap: () {
          SemanticsService.sendAnnouncement(
            View.of(context),
            '$displayName selected',
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
                Expanded(
                  child: Text(
                    displayName,
                    style: TribelyType.bodyM(labelColor),
                  ),
                ),
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
