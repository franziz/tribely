import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/validators/event_validators.dart';
import '../providers/events_providers.dart';
import '../state/create_event_state.dart';
import '../widgets/event_form_field.dart';

/// Step 5 — Description + Review.
///
/// Shows a multiline description field followed by a read-only "Review" section
/// summarising every prior step's values. Each review row has a pencil icon
/// that navigates back to the owning step via [CreateEventController.goToStep].
///
/// The Publish CTA lives in [StepNavigationBar], not here.
class CreateEventStep5DescribePage extends ConsumerWidget {
  const CreateEventStep5DescribePage({super.key});

  static final _dateFormat = DateFormat('EEE d MMM y, h:mm a');

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
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // Description field — multiline
          EventFormField(
            label: 'Description',
            value: draft.description,
            errorText: errors['description'],
            maxLines: 8,
            minLines: 5,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            hint:
                'Tell people what to expect — vibe, what to bring, dress code…',
            onChanged: (v) =>
                controller.updateField(field: 'description', value: v),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '$descriptionMinLenUi–$descriptionMaxLen characters',
              style: TribelyType.caption(inkSecondary),
            ),
          ),

          const SizedBox(height: 28),

          // Review section header
          Text('Review', style: TribelyType.headline(ink)),
          const SizedBox(height: 4),
          Text(
            'Double-check your details before publishing.',
            style: TribelyType.bodyM(inkSecondary),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              border: Border.all(color: border, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Step 1 — Title + Category
                _ReviewRow(
                  icon: Icons.event_note_outlined,
                  label: 'Basics',
                  value: [
                    draft.title ?? '—',
                    draft.category?.displayName ?? '—',
                  ].join(' · '),
                  onEdit: () => controller.goToStep(0),
                  showDivider: true,
                ),

                // Step 2 — Venue
                _ReviewRow(
                  icon: Icons.place_outlined,
                  label: 'Venue',
                  value: _venueReview(
                    draft.venueName,
                    draft.latitude,
                    draft.longitude,
                  ),
                  onEdit: () => controller.goToStep(1),
                  showDivider: true,
                ),

                // Step 3 — When
                _ReviewRow(
                  icon: Icons.access_time_outlined,
                  label: 'When',
                  value: _whenReview(draft.startsAt, draft.endsAt),
                  onEdit: () => controller.goToStep(2),
                  showDivider: true,
                ),

                // Step 4 — Logistics
                _ReviewRow(
                  icon: Icons.people_outline,
                  label: 'Logistics',
                  value: _logisticsReview(draft.capacity, draft.approvalMode),
                  onEdit: () => controller.goToStep(3),
                  showDivider: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _venueReview(String? name, double? lat, double? lng) {
    if (name == null && lat == null && lng == null) return '—';
    final parts = <String>[];
    if (name != null) parts.add(name);
    if (lat != null && lng != null) {
      parts.add('${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}');
    }
    return parts.join('\n');
  }

  String _whenReview(DateTime? starts, DateTime? ends) {
    if (starts == null && ends == null) return '—';
    final buffer = StringBuffer();
    if (starts != null) buffer.write('Starts: ${_dateFormat.format(starts)}');
    if (ends != null) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write('Ends: ${_dateFormat.format(ends)}');
    }
    return buffer.toString();
  }

  String _logisticsReview(int? capacity, String? approvalMode) {
    final parts = <String>[];
    if (capacity != null) parts.add('$capacity people');
    if (approvalMode != null) {
      parts.add(approvalMode == 'auto' ? 'Auto-approve' : 'Manual approval');
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
    required this.showDivider,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
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
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TribelyType.caption(inkSecondary)),
                    const SizedBox(height: 2),
                    Text(value, style: TribelyType.bodyM(ink)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 18, color: inkSecondary),
                tooltip: 'Edit $label',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(color: border, height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
