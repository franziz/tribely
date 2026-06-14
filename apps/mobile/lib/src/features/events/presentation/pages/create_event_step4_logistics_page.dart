import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/validators/event_validators.dart';
import '../providers/events_providers.dart';
import '../state/create_event_state.dart';
import '../widgets/event_form_field.dart';

/// Step 4 — Logistics (capacity + approval mode).
///
/// Capacity is a numeric text field, UI-clamped to [capacityUiClamp] = 50
/// (server accepts up to [capacityMax] = 1000 — the UI is intentionally more
/// conservative per PM brief). Approval mode is rendered as [RadioListTile]s.
class CreateEventStep4LogisticsPage extends ConsumerWidget {
  const CreateEventStep4LogisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createEventControllerProvider);
    if (state is! CreateEventEditing) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(createEventControllerProvider.notifier);
    final draft = state.formData;
    final errors = state.fieldErrors;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // Capacity field — numeric, UI-clamped to 50
          EventFormField(
            label: 'Capacity',
            value: draft.capacity?.toString(),
            errorText: errors['capacity'],
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            hint: '2–$capacityUiClamp',
            onChanged: (v) {
              final parsed = int.tryParse(v.trim());
              // UI clamp: silently cap at capacityUiClamp so the user can't
              // accidentally enter a value the UI is not designed for. Server
              // still enforces its own maximum of capacityMax = 1000.
              final clamped = parsed?.clamp(capacityMin, capacityUiClamp);
              controller.updateField(field: 'capacity', value: clamped);
            },
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Max $capacityUiClamp people per event',
              style: TribelyType.caption(inkSecondary),
            ),
          ),

          const SizedBox(height: 24),

          // Approval mode
          Text('Who can join?', style: TribelyType.headline(ink)),
          const SizedBox(height: 4),
          Text(
            'Choose how participants join your event.',
            style: TribelyType.bodyM(inkSecondary),
          ),
          const SizedBox(height: 12),

          RadioGroup<String>(
            groupValue: draft.approvalMode,
            onChanged: (v) =>
                controller.updateField(field: 'approvalMode', value: v),
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'auto',
                  title: Text(
                    'Anyone can join instantly',
                    style: TribelyType.bodyM(ink),
                  ),
                  subtitle: Text(
                    'Requests are automatically approved.',
                    style: TribelyType.caption(inkSecondary),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  value: 'manual',
                  title: Text(
                    'I review join requests',
                    style: TribelyType.bodyM(ink),
                  ),
                  subtitle: Text(
                    'You approve or decline each request.',
                    style: TribelyType.caption(inkSecondary),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          if (errors['approvalMode'] != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                errors['approvalMode']!,
                style: TribelyType.caption(accent),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Cost notes — optional free-text field (CEO guardrail: plain String
          // only, never numeric/structured cost input). Empty value never gates
          // canAdvance or canSubmit — costNotes is intentionally absent from
          // _stepFields. Counter hidden below 150 chars; shows N/200 from 150+.
          EventFormField(
            key: const ValueKey('costNotes'),
            label: 'Cost notes',
            value: draft.costNotes,
            errorText: errors['costNotes'],
            maxLength: costNotesMaxLen,
            keyboardType: TextInputType.multiline,
            maxLines: 3,
            minLines: 1,
            hint:
                'Optional — e.g. "Pay your own way" or "I\'ll cover snacks, you grab drinks"',
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    currentLength < 150
                    ? null
                    : Text(
                        '$currentLength/$costNotesMaxLen',
                        style: TribelyType.caption(inkSecondary),
                      ),
            onChanged: (v) => controller.updateField(
              field: 'costNotes',
              value: v.isEmpty ? null : v,
            ),
          ),
        ],
      ),
    );
  }
}
