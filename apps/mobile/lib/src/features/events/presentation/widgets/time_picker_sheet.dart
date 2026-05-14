import 'dart:ui' show TextDirection;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';

/// Pattern B — Time sheet.
///
/// Presents a scrollable list of 96 15-minute time-of-day slots and returns
/// a combined [DateTime] (using [pickedDate] for the date component and the
/// selected row for the time component) via [Navigator.pop]. Cancelling pops
/// with null.
///
/// Layout (per TRI-61 spec lines 236–370):
///   - Drag handle.
///   - Headline "Pick a time".
///   - Sub-label: [DateFormat('EEE d MMM').format(pickedDate)].
///   - Divider.
///   - Expanded [ListView.separated] of 96 rows (00:00–23:45, 15-min slots).
///   - Divider.
///   - [PrimaryButton] "Confirm time" (disabled until row selected).
///   - TextButton "Cancel".
///   - Safe-area bottom inset.
///
/// Sheet height is fixed at 85% of screen height via [FractionallySizedBox]
/// so that [Expanded] resolves correctly.
///
/// Unavailable rows (today + time ≤ now + 5 min) are rendered in muted ink
/// and are not tappable. Pre-scroll centres the selected/best-guess row after
/// the first frame via [ScrollController.jumpTo].
///
/// Returns [DateTime?] via [Navigator.pop].
///
/// Usage:
/// ```dart
/// final result = await showModalBottomSheet<DateTime?>(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   isDismissible: true,
///   enableDrag: true,
///   useRootNavigator: false,
///   builder: (_) => TimePickerSheet(
///     pickedDate: pickedDate,
///     initialValue: existingValue,
///   ),
/// );
/// ```
class TimePickerSheet extends StatefulWidget {
  const TimePickerSheet({
    required this.pickedDate,
    this.initialValue,
    super.key,
  });

  /// The date already confirmed by the date sheet. Used for the sub-label and
  /// for determining which rows are unavailable (if this date is today).
  final DateTime pickedDate;

  /// Optional existing [DateTime] for the field. If non-null AND the date
  /// component matches [pickedDate], the nearest 15-minute bucket is
  /// pre-selected.
  final DateTime? initialValue;

  @override
  State<TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<TimePickerSheet> {
  static const int _rowCount = 96; // 24 * 4
  static const double _rowHeight = 57.0; // 56dp row + 1dp separator

  late final ScrollController _scrollController;
  int? _selectedIndex;

  // Pre-computed so [build] stays lean.
  late final bool _isToday;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _isToday = _isSameDate(widget.pickedDate, DateTime.now());

    // Resolve pre-selected index from initialValue if it falls on pickedDate.
    if (widget.initialValue != null &&
        _isSameDate(widget.initialValue!, widget.pickedDate)) {
      final v = widget.initialValue!;
      _selectedIndex = (v.hour * 4) + (v.minute ~/ 15);
    }

    // Defer the jump until after the first frame — ScrollController needs a
    // viewport to calculate maxScrollExtent.
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToInitialRow());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// True when [index] refers to a past/unavailable slot for today.
  bool _isUnavailable(int index) {
    if (!_isToday) return false;
    final now = DateTime.now();
    final rowHour = index ~/ 4;
    final rowMinute = (index % 4) * 15;
    final rowTime = DateTime(now.year, now.month, now.day, rowHour, rowMinute);
    return rowTime.isBefore(now.add(const Duration(minutes: 5)));
  }

  int get _bestGuessIndex {
    final now = DateTime.now();
    return ((now.hour * 4) + (now.minute ~/ 15)).clamp(0, _rowCount - 1);
  }

  DateTime get _combinedDateTime {
    final idx = _selectedIndex!;
    final h = idx ~/ 4;
    final m = (idx % 4) * 15;
    return DateTime(
      widget.pickedDate.year,
      widget.pickedDate.month,
      widget.pickedDate.day,
      h,
      m,
    );
  }

  String _formatRowTime(int index) {
    final h = index ~/ 4;
    final m = (index % 4) * 15;
    return DateFormat('h:mm a').format(DateTime(0, 1, 1, h, m));
  }

  void _jumpToInitialRow() {
    if (!_scrollController.hasClients) return;
    final targetIndex = _selectedIndex ?? _bestGuessIndex;
    final viewportHeight = _scrollController.position.viewportDimension;
    final offset = (targetIndex * _rowHeight - (viewportHeight / 2 - 28)).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(offset);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pick a time dialog',
      explicitChildNodes: true,
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          decoration: const BoxDecoration(
            color: TribelyColors.paperSurfaceHigh,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Drag handle.
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
              // Headline + sub-label.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pick a time',
                    style: TribelyType.headline(TribelyColors.paperInkPrimary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    DateFormat('EEE d MMM').format(widget.pickedDate),
                    style: TribelyType.caption(TribelyColors.paperInkSecondary),
                  ),
                ),
              ),
              // Header divider.
              const Divider(
                height: 1,
                thickness: 1,
                color: TribelyColors.paperBorderSubtle,
              ),
              // Scrollable time rows.
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: _rowCount,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: TribelyColors.paperBorderSubtle,
                  ),
                  itemBuilder: (context, i) => _TimeRow(
                    index: i,
                    label: _formatRowTime(i),
                    isSelected: _selectedIndex == i,
                    isUnavailable: _isUnavailable(i),
                    onTap: () {
                      final label = _formatRowTime(i);
                      setState(() => _selectedIndex = i);
                      // ignore: deprecated_member_use
                      // sendAnnouncement requires FlutterView (needs BuildContext
                      // threaded through VoidCallback) — deferred to a future cycle.
                      SemanticsService.announce(
                        '$label selected',
                        TextDirection.ltr,
                      );
                    },
                  ),
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
                      label: 'Confirm time',
                      onPressed: _selectedIndex == null
                          ? null
                          : () => Navigator.pop(context, _combinedDateTime),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TimeRow
// ---------------------------------------------------------------------------

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.index,
    required this.label,
    required this.isSelected,
    required this.isUnavailable,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool isSelected;
  final bool isUnavailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? TribelyColors.paperPrimary
        : isUnavailable
        ? TribelyColors.paperInkSecondary.withAlpha(80)
        : TribelyColors.paperInkPrimary;

    final semanticsLabel = [
      label,
      if (isSelected) ', selected',
      if (isUnavailable) ', unavailable',
    ].join();

    return Semantics(
      label: semanticsLabel,
      button: !isUnavailable,
      enabled: !isUnavailable,
      child: isUnavailable
          ? _RowContent(label: label, textColor: textColor, isSelected: false)
          : InkWell(
              onTap: onTap,
              splashColor: TribelyColors.paperPrimary.withAlpha(20),
              highlightColor: TribelyColors.paperPrimary.withAlpha(10),
              child: _RowContent(
                label: label,
                textColor: textColor,
                isSelected: isSelected,
              ),
            ),
    );
  }
}

class _RowContent extends StatelessWidget {
  const _RowContent({
    required this.label,
    required this.textColor,
    required this.isSelected,
  });

  final String label;
  final Color textColor;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Text(label, style: TribelyType.bodyM(textColor)),
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
    );
  }
}
