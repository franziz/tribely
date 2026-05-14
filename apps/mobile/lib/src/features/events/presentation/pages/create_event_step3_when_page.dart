import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../providers/events_providers.dart';
import '../state/create_event_state.dart';
import '../widgets/date_time_picker_field.dart';

/// Step 3 — When.
///
/// Provides date+time pickers for start and end times using the Pattern B
/// separated sheet flow: a [DatePickerSheet] opens first (Cupertino date
/// wheel), then a [TimePickerSheet] (96-row scrollable 15-minute grid).
/// Times are displayed in the user's local clock but labeled as
/// "Singapore Time (UTC+8)" since the app is Singapore-first and no timezone
/// picker is offered in v1.
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
          DateTimePickerField(
            label: 'Starts at',
            value: draft.startsAt,
            errorText: errors['startsAt'],
            onPicked: (dt) =>
                controller.updateField(field: 'startsAt', value: dt),
          ),
          const SizedBox(height: 20),
          DateTimePickerField(
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

class _TimezoneLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

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
