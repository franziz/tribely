import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../providers/events_providers.dart';
import '../state/create_event_state.dart';

/// Step 3 — When.
///
/// Provides date+time pickers for start and end times using the standard
/// Material [showDatePicker] + [showTimePicker] pair. Times are displayed in
/// the user's local clock but labeled as "Singapore Time (UTC+8)" since the
/// app is Singapore-first and no timezone picker is offered in v1.
///
/// Inline errors from [fieldErrors] are shown below each picker row.
class CreateEventStep3WhenPage extends ConsumerWidget {
  const CreateEventStep3WhenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createEventControllerProvider);
    if (state is! CreateEventEditing) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(createEventControllerProvider.notifier);
    final draft = state.formData;
    final errors = state.fieldErrors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _DateTimePicker(
            label: 'Starts at',
            value: draft.startsAt,
            errorText: errors['startsAt'],
            onPicked: (dt) =>
                controller.updateField(field: 'startsAt', value: dt),
          ),
          const SizedBox(height: 20),
          _DateTimePicker(
            label: 'Ends at',
            value: draft.endsAt,
            errorText: errors['endsAt'],
            onPicked: (dt) =>
                controller.updateField(field: 'endsAt', value: dt),
          ),
          const SizedBox(height: 16),
          _TimezoneLabel(),
        ],
      ),
    );
  }
}

/// Tappable row that opens a date picker followed by a time picker and
/// combines the result into a [DateTime].
class _DateTimePicker extends StatelessWidget {
  const _DateTimePicker({
    required this.label,
    required this.onPicked,
    this.value,
    this.errorText,
  });

  final String label;
  final DateTime? value;
  final String? errorText;
  final ValueChanged<DateTime> onPicked;

  static final _format = DateFormat('EEE d MMM y, h:mm a');

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = value ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null) return;
    if (!context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: value != null
          ? TimeOfDay.fromDateTime(value!)
          : TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    onPicked(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        dark ? TribelyColors.nightInkPrimary : TribelyColors.paperInkPrimary;
    final inkSecondary =
        dark ? TribelyColors.nightInkSecondary : TribelyColors.paperInkSecondary;
    final border =
        dark ? TribelyColors.nightBorderSubtle : TribelyColors.paperBorderSubtle;
    final primary =
        dark ? TribelyColors.nightPrimary : TribelyColors.paperPrimary;
    final accent =
        dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

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
                        value != null
                            ? _format.format(value!)
                            : 'Tap to select',
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
            child: Text(
              errorText!,
              style: TribelyType.caption(accent),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimezoneLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary =
        dark ? TribelyColors.nightInkSecondary : TribelyColors.paperInkSecondary;

    return Row(
      children: [
        Icon(Icons.public, size: 14, color: inkSecondary),
        const SizedBox(width: 6),
        Text(
          'Singapore Time (UTC+8)',
          style: TribelyType.caption(inkSecondary),
        ),
      ],
    );
  }
}
