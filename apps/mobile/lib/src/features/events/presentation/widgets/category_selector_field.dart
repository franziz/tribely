import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/entities/event_category.dart';
import 'category_icons.dart';
import 'category_sheet.dart';

/// Pattern A trigger widget for the create-event Step 1 category field.
///
/// A purely presentational [StatelessWidget] — no Riverpod, no [FormField].
/// The parent page owns all state and validation; this widget renders it.
///
/// Responsibilities:
/// - Render the trigger row (icon, label, value, chevron) per the TRI-61
///   Pattern A spec, switching to accent border on error.
/// - On tap: unfocus, then open [CategorySheet] via [showModalBottomSheet].
/// - If the sheet returns a non-null [EventCategory], call [onChanged].
/// - Render the [errorText] below the row when non-null.
class CategorySelectorField extends StatelessWidget {
  const CategorySelectorField({
    required this.value,
    required this.errorText,
    required this.onChanged,
    super.key,
  });

  /// The currently selected category, or null if none has been chosen yet.
  final EventCategory? value;

  /// Validation error text sourced from the controller's [fieldErrors].
  /// When non-null the trigger border switches to [paperAccent] and the text
  /// is rendered below the trigger row, matching [EventFormField]'s placement.
  final String? errorText;

  /// Invoked with the newly selected [EventCategory] after the sheet returns.
  /// Callers should forward this to the controller's [updateField].
  final ValueChanged<EventCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final hasValue = value != null;

    final borderColor = hasError
        ? TribelyColors.paperAccent
        : TribelyColors.paperBorderSubtle;

    final leadingIconData = hasValue
        ? kCategoryIcons[value!]!
        : Icons.category_outlined;
    final leadingIconColor = hasValue
        ? TribelyColors.paperPrimary
        : TribelyColors.paperInkSecondary;
    final valueTextColor = hasValue
        ? TribelyColors.paperInkPrimary
        : TribelyColors.paperInkSecondary;
    final valueText = hasValue ? value!.displayName : 'Tap to select';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trigger row.
        GestureDetector(
          onTap: () => _onTriggerTap(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: TribelyColors.paperSurfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(leadingIconData, size: 18, color: leadingIconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Category',
                        style: TribelyType.caption(
                          TribelyColors.paperInkSecondary,
                        ),
                      ),
                      Text(valueText, style: TribelyType.bodyM(valueTextColor)),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: TribelyColors.paperInkSecondary,
                ),
              ],
            ),
          ),
        ),
        // Error text — rendered only when errorText is non-null.
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              errorText!,
              style: TribelyType.caption(TribelyColors.paperAccent),
            ),
          ),
      ],
    );
  }

  Future<void> _onTriggerTap(BuildContext context) async {
    // Dismiss the keyboard before the sheet opens — matches the spec's L-risk 1
    // call-order requirement and ConfirmJoinSheet's precedent.
    FocusManager.instance.primaryFocus?.unfocus();

    final result = await showModalBottomSheet<EventCategory?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => CategorySheet(initial: value),
    );

    if (result != null) {
      onChanged(result);
    }
  }
}
