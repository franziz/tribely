import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import 'date_picker_sheet.dart';
import 'time_picker_sheet.dart';

/// Tappable trigger row that chains the Pattern B date sheet followed by the
/// Pattern B time sheet, then calls [onPicked] with the combined [DateTime].
///
/// This widget replaces the private `_DateTimePicker` in
/// `create_event_step3_when_page.dart`. The trigger-row visual is preserved
/// byte-for-byte (including dark-mode color branches).
///
/// Flow:
/// 1. User taps the row → keyboard focus cleared → [DatePickerSheet] opens.
/// 2. User confirms date → sheet closes → [TimePickerSheet] opens immediately.
/// 3. User confirms time → combined [DateTime] passed to [onPicked].
/// 4. Cancel on either sheet → flow aborted; [onPicked] not called; existing
///    [value] unchanged.
///
/// Design spec: TRI-61 Pattern B, trigger row lines 201–206 + L-risk 1.
class DateTimePickerField extends StatelessWidget {
  const DateTimePickerField({
    required this.label,
    required this.onPicked,
    this.value,
    this.errorText,
    super.key,
  });

  /// Field label shown above the value text (e.g. "Starts at").
  final String label;

  /// Currently committed value. null = empty/"Tap to select" placeholder.
  final DateTime? value;

  /// Inline error text rendered below the trigger row in accent color.
  final String? errorText;

  /// Called with the fully-combined [DateTime] after the user confirms both
  /// the date and time sheets. NOT called on cancel.
  final ValueChanged<DateTime> onPicked;

  static final _format = DateFormat('EEE d MMM y, h:mm a');

  Future<void> _pick(BuildContext context) async {
    // L-risk 1: dismiss keyboard before opening sheet.
    FocusManager.instance.primaryFocus?.unfocus();

    final now = DateTime.now();
    final initialDate = value ?? now.add(const Duration(hours: 1));

    // Step 1 — date sheet.
    final pickedDate = await showModalBottomSheet<DateTime?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      useRootNavigator: false,
      builder: (_) => DatePickerSheet(initial: initialDate),
    );
    if (pickedDate == null) return;
    if (!context.mounted) return;

    // Step 2 — time sheet (chained immediately after date confirm).
    final result = await showModalBottomSheet<DateTime?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      useRootNavigator: false,
      builder: (_) => TimePickerSheet(
        pickedDate: pickedDate,
        initialValue: value,
      ),
    );
    if (result == null) return;

    onPicked(result);
  }

  @override
  Widget build(BuildContext context) {
    // Trigger-row colors — dark-mode branches preserved for parity with the
    // original _DateTimePicker implementation.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final primary = dark ? TribelyColors.nightPrimary : TribelyColors.paperPrimary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: hasError ? accent : border,
                width: hasError ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 18, color: primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TribelyType.caption(inkSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        value != null ? _format.format(value!) : 'Tap to select',
                        style: TribelyType.bodyM(
                          value != null ? ink : inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: inkSecondary),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(errorText!, style: TribelyType.caption(accent)),
          ),
        ],
      ],
    );
  }
}
