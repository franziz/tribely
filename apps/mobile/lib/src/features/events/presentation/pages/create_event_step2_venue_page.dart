import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../providers/events_providers.dart';
import '../state/create_event_state.dart';
import '../widgets/event_form_field.dart';

/// Step 2 — Venue.
///
/// Renders venue name, latitude, and longitude fields. Lat/lng use a
/// signed-decimal numeric keyboard. Parse failures are communicated to the
/// controller as null, which the validator converts to a user-visible error.
///
/// A read-only placeholder links to the future map-picker (TRI-23).
class CreateEventStep2VenuePage extends ConsumerWidget {
  const CreateEventStep2VenuePage({super.key});

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
    final inkSecondary =
        dark ? TribelyColors.nightInkSecondary : TribelyColors.paperInkSecondary;
    final border =
        dark ? TribelyColors.nightBorderSubtle : TribelyColors.paperBorderSubtle;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          EventFormField(
            label: 'Venue name',
            value: draft.venueName,
            errorText: errors['venueName'],
            textInputAction: TextInputAction.next,
            hint: 'e.g. Bukit Timah Nature Reserve',
            onChanged: (v) =>
                controller.updateField(field: 'venueName', value: v),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: EventFormField(
                  label: 'Latitude',
                  value: draft.latitude?.toString(),
                  errorText: errors['latitude'],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.next,
                  hint: '1.3521',
                  onChanged: (v) {
                    final parsed = double.tryParse(v.trim());
                    controller.updateField(field: 'latitude', value: parsed);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: EventFormField(
                  label: 'Longitude',
                  value: draft.longitude?.toString(),
                  errorText: errors['longitude'],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.done,
                  hint: '103.8198',
                  onChanged: (v) {
                    final parsed = double.tryParse(v.trim());
                    controller.updateField(field: 'longitude', value: parsed);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Non-functional placeholder for the future map picker (TRI-23).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: border, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: inkSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap to pick on map (coming soon)',
                  style: TribelyType.bodyM(inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
