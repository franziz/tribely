import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../domain/entities/venue_category.dart';
import '../providers/events_providers.dart';
import '../state/create_event_state.dart';
import '../widgets/event_form_field.dart';
import '../widgets/venue_type_chip.dart';

// ---------------------------------------------------------------------------
// Human-readable labels for public venue categories.
// Maintained as a local constant to avoid mutating domain entities for display
// concerns. Order matches [VenueCategory.publicValues] iteration order so the
// chip grid is deterministic across rebuilds.
// ---------------------------------------------------------------------------

/// Ordered list of (categoryValue, humanLabel) pairs for the chip grid.
///
/// Only public values are listed here. The list is ordered by expected
/// frequency of use for Singapore solo travellers — cafe and hawker centre
/// first, then parks, restaurants, etc.
const List<(String, String)> _publicVenueLabelPairs = [
  ('cafe', 'Cafe'),
  ('hawker_centre', 'Hawker centre'),
  ('restaurant', 'Restaurant'),
  ('bar', 'Bar'),
  ('park', 'Park'),
  ('beach', 'Beach'),
  ('museum', 'Museum'),
  ('library', 'Library'),
  ('mrt_landmark', 'MRT landmark'),
  ('community_centre', 'Community centre'),
  ('shopping_mall_common_area', 'Shopping mall'),
  ('tourist_attraction', 'Tourist attraction'),
];

// Verify at compile-time that the label list covers every public value.
// If [VenueCategory.publicValues] is extended on the server and [venue_category.dart]
// is updated but this list is not, the assertion below will fire in debug mode.
// (Dart doesn't support static assertions, so this is a debug-mode runtime guard.)
void _assertLabelCoverage() {
  assert(
    _publicVenueLabelPairs.length == VenueCategory.publicValues.length &&
        _publicVenueLabelPairs
            .map((p) => p.$1)
            .toSet()
            .containsAll(VenueCategory.publicValues),
    'venue_type_chip label list is out of sync with VenueCategory.publicValues. '
    'Update _publicVenueLabelPairs in create_event_step2_venue_page.dart.',
  );
}

/// Step 2 — Venue.
///
/// Renders:
///  1. A section heading "Public places in Singapore" + horizontally-scrolling
///     chip grid of [VenueCategory.publicValues] (single-select).
///  2. Free-text venue name field.
///  3. Latitude / longitude fields.
///  4. A non-functional map-picker placeholder (TRI-23).
///  5. A private-venue warning banner below the venue name field when
///     [CreateEventEditing.privateVenueWarning] is non-None.
///  6. A non-blocking chip nudge near the chip grid when
///     [CreateEventEditing.venueCategoryNudge] is true.
///
/// The "Next" button remains enabled when venue name is present regardless of
/// chip selection — [selectVenueCategory] is encouraged but not required here.
/// The server enforces the policy at publish time (Brief 11 modal).
class CreateEventStep2VenuePage extends ConsumerWidget {
  const CreateEventStep2VenuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger the compile-time coverage assertion in debug mode on first build.
    assert(() {
      _assertLabelCoverage();
      return true;
    }());

    final state = ref.watch(createEventControllerProvider);
    if (state is! CreateEventEditing) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(createEventControllerProvider.notifier);
    final draft = state.formData;
    final errors = state.fieldErrors;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final accentColor = dark
        ? TribelyColors.nightAccent
        : TribelyColors.paperAccent;

    final showWarning = switch (state.privateVenueWarning) {
      PrivateVenueWarningNone() => false,
      PrivateVenueWarningFirstTimeHost() => true,
      PrivateVenueWarningEstablishedHost() => true,
    };

    final warningMessage = switch (state.privateVenueWarning) {
      PrivateVenueWarningFirstTimeHost() =>
        'Tribely events meet in public. Your first event must be at a public '
            'spot like a cafe, park, or hawker centre.',
      PrivateVenueWarningEstablishedHost() =>
        'Public spots get more joiners. Private venues are allowed but discouraged.',
      PrivateVenueWarningNone() => '',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // ---------------------------------------------------------------
          // 1. Public-places section heading
          // ---------------------------------------------------------------
          Text(
            'Public places in Singapore',
            style: TribelyType.caption(
              inkSecondary,
            ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
          const SizedBox(height: 10),

          // ---------------------------------------------------------------
          // 2. Chip grid — horizontally scrollable single-select
          // ---------------------------------------------------------------
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _publicVenueLabelPairs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (value, label) = _publicVenueLabelPairs[index];
                return VenueTypeChip(
                  value: value,
                  label: label,
                  isSelected: state.selectedVenueCategory == value,
                  onTap: () => controller.selectVenueCategory(value),
                );
              },
            ),
          ),

          // ---------------------------------------------------------------
          // 3. Non-blocking nudge when the user tapped Next without a chip
          // ---------------------------------------------------------------
          if (state.venueCategoryNudge) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                'Pick a venue type',
                style: TribelyType.caption(accentColor),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ---------------------------------------------------------------
          // 4. Venue name field
          // ---------------------------------------------------------------
          EventFormField(
            label: 'Venue name',
            value: draft.venueName,
            errorText: errors['venueName'],
            textInputAction: TextInputAction.next,
            hint: 'e.g. Bukit Timah Nature Reserve',
            onChanged: controller.onVenueNameChanged,
          ),

          // ---------------------------------------------------------------
          // 5. Private-venue warning banner
          // ---------------------------------------------------------------
          if (showWarning) ...[
            const SizedBox(height: 12),
            BannerMessage(message: warningMessage),
          ],

          const SizedBox(height: 20),

          // ---------------------------------------------------------------
          // 6. Latitude / longitude row
          // ---------------------------------------------------------------
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

          // ---------------------------------------------------------------
          // 7. Non-functional map picker placeholder (TRI-23)
          // ---------------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: border, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.map_outlined, size: 18, color: inkSecondary),
                const SizedBox(width: 8),
                Text(
                  'Tap to pick on map (coming soon)',
                  style: TribelyType.bodyM(inkSecondary),
                ),
              ],
            ),
          ),

          // Bottom padding so the last field isn't obscured by the nav bar.
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
        ],
      ),
    );
  }
}
