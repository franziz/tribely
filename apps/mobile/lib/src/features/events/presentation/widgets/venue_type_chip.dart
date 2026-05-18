import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';

/// A single-select chip used on Step 2 of create-event to classify the
/// venue as one of the public [VenueCategory.publicValues].
///
/// Visual language mirrors TRI-87's category bottom-sheet selector:
/// selected state uses [TribelyColors.paperPrimary] fill + white label;
/// unselected state uses [TribelyColors.paperBorderSubtle] border + ink label.
///
/// Tap target is ≥ 44pt as required by WCAG 2.5.5.
///
/// Accessibility: [Semantics.label] is "$label venue type, selected/not selected"
/// so screen-reader users understand both the content and its selection state.
class VenueTypeChip extends StatelessWidget {
  const VenueTypeChip({
    required this.value,
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  /// The canonical snake_case venue category string (e.g. `'cafe'`).
  final String value;

  /// Human-readable label shown on the chip (e.g. `'Cafe'`).
  final String label;

  /// Whether this chip is the currently-selected venue category.
  final bool isSelected;

  /// Callback fired when the chip is tapped. The parent is responsible for
  /// updating the controller — this widget holds no local state.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final inkPrimary = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final surfaceHigh = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;

    final backgroundColor = isSelected ? primary : surfaceHigh;
    final labelColor = isSelected
        ? (dark ? TribelyColors.nightSurface : TribelyColors.paperSurfaceHigh)
        : inkPrimary;
    final borderColor = isSelected ? primary : border;

    final semanticsLabel =
        '$label venue type, ${isSelected ? "selected" : "not selected"}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          // Minimum 44pt tap target height (WCAG 2.5.5).
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TribelyType.caption(labelColor).copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
