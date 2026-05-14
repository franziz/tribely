import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';

/// Pattern B — Date sheet.
///
/// Presents a [CupertinoDatePicker] in date-only mode and returns the
/// confirmed [DateTime] via [Navigator.pop]. Cancelling pops with null.
///
/// Layout (per TRI-61 spec lines 209–230):
///   - Drag handle: 32×4dp centred, top:12.
///   - Headline "Pick a date": headline/22 inkPrimary, left:24, top:16.
///   - Divider.
///   - [CupertinoDatePicker] constrained to 200dp height.
///   - Divider.
///   - [PrimaryButton] "Confirm date", horiz pad:24.
///   - TextButton "Cancel".
///   - Safe-area bottom inset: [MediaQuery.paddingOf(context).bottom + 8].
///
/// Returns [DateTime?] via [Navigator.pop]. The caller is responsible for
/// chaining the time sheet after receiving a non-null result.
///
/// Usage:
/// ```dart
/// final date = await showModalBottomSheet<DateTime?>(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   isDismissible: true,
///   enableDrag: true,
///   useRootNavigator: false,
///   builder: (_) => DatePickerSheet(initial: initialDate),
/// );
/// ```
class DatePickerSheet extends StatefulWidget {
  const DatePickerSheet({required this.initial, super.key});

  /// The date pre-selected when the sheet opens.
  final DateTime initial;

  @override
  State<DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<DatePickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Semantics(
      label: 'Pick a date dialog',
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
                  'Pick a date',
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
            // Date picker — constrained to 200dp per spec line 216.
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selected,
                minimumDate: DateTime(now.year, now.month, now.day),
                maximumDate: now.add(const Duration(days: 730)),
                backgroundColor: TribelyColors.paperSurfaceHigh,
                onDateTimeChanged: (d) => setState(() => _selected = d),
              ),
            ),
            // Footer divider.
            const Divider(
              height: 1,
              thickness: 1,
              color: TribelyColors.paperBorderSubtle,
            ),
            // Confirm + Cancel + safe-area padding.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Confirm date',
                    onPressed: () => Navigator.pop(context, _selected),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: Text(
                        'Cancel',
                        style: TribelyType.button(
                          TribelyColors.paperInkSecondary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
