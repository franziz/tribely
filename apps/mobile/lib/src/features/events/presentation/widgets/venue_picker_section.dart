import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/place_result_row.dart';
import '../../../../core/widgets/place_search_field.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../domain/entities/event_draft.dart';
import '../../domain/entities/place_details.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/services/provider_category_mapper.dart';
import '../controllers/venue_picker_controller.dart';
import '../providers/events_providers.dart';
import '../providers/venue_picker_providers.dart';
import '../state/create_event_state.dart';
import '../state/venue_picker_state.dart';
import '../widgets/free_text_disambiguation_field.dart';
import '../widgets/static_map_preview.dart';

// ---------------------------------------------------------------------------
// Copy constants — locked per EL brief
// ---------------------------------------------------------------------------

const String _kQuotaCopy =
    'Search is temporarily unavailable. Enter the venue name manually below.';

const String _kNoCoordsCopy =
    "This venue couldn't be located on the map. Try a different name or enter "
    'manually.';

const String _kEmptyPrimary = 'No matches in Singapore.';
const String _kEmptySecondary =
    'Try a different name, or enter a venue name manually below.';

/// Height of each skeleton placeholder row during the [VenuePickerSearching]
/// state. Matches the minimum height of [PlaceResultRow] (64dp).
const double _kSkeletonRowHeight = 64.0;

/// Number of skeleton rows to show while searching.
const int _kSkeletonRowCount = 3;

/// The main venue-picker composition widget for Step 2 of the create-event
/// wizard.
///
/// Composes [PlaceSearchField], [PlaceResultRow], [StaticMapPreview],
/// [FreeTextDisambiguationField], and [BannerMessage] based on the current
/// [VenuePickerState].
///
/// Side-effect bridge: uses [ref.listen] on [venuePickerControllerProvider] to
/// write venue fields into [EventDraft] via [createEventControllerProvider.notifier].
///
/// Layout contract (Brief F):
///   - [PlaceSearchField] is always at the top.
///   - Body area switches on [VenuePickerState] (see [_buildBody]).
///   - [FreeTextDisambiguationField] is shown in Initial / Empty / Degraded* /
///     NoCoords states; hidden in Selected state per designer spec.
class VenuePickerSection extends ConsumerStatefulWidget {
  const VenuePickerSection({super.key});

  @override
  ConsumerState<VenuePickerSection> createState() => _VenuePickerSectionState();
}

class _VenuePickerSectionState extends ConsumerState<VenuePickerSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // EventDraft side-effect writers
  // ---------------------------------------------------------------------------

  void _onVenueSelected(VenuePickerSelected next, CreateEventEditing editing) {
    final details = next.details;
    final controller = ref.read(createEventControllerProvider.notifier);

    // Write lat/lng — these are the canAdvance gate fields.
    controller.updateField(field: 'latitude', value: details.latitude);
    controller.updateField(field: 'longitude', value: details.longitude);

    // venueName: always set to the provider's name so the API submission
    // carries the canonical place name. If the user has typed a
    // venueDisplayNameOverride, display logic at render time layers it on
    // top — venueName stays as the provider's canonical name.
    controller.updateField(field: 'venueName', value: details.name);

    // Write provider-specific fields (providerPlaceId, venueAddress,
    // rawProviderCategory) via the dedicated controller method.
    controller.applyVenueDetails(
      providerPlaceId: details.providerPlaceId,
      venueAddress: details.formattedAddress,
      rawProviderCategory: details.rawCategory,
    );

    // Auto-apply TRI-33 chip: map raw provider category → Tribely venue
    // category. Preserve existing chip selection when the mapper returns null.
    final mappedCategory = mapProviderCategoryToVenueCategory(
      details.rawCategory,
    );
    if (mappedCategory != null) {
      controller.selectVenueCategory(mappedCategory);
    }
  }

  void _onVenueCleared() {
    final controller = ref.read(createEventControllerProvider.notifier);
    controller.clearVenueSelection();
  }

  void _onFreeTextChanged(String? value) {
    final controller = ref.read(createEventControllerProvider.notifier);
    controller.updateVenueDisplayNameOverride(value);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Side-effect bridge: sync picker state transitions → EventDraft writes.
    // Using ref.listen (NOT ref.watch) for side effects per Riverpod convention.
    ref.listen<VenuePickerState>(venuePickerControllerProvider, (
      previous,
      next,
    ) {
      final editingState = ref.read(createEventControllerProvider);
      if (editingState is! CreateEventEditing) return;

      if (next is VenuePickerSelected) {
        _onVenueSelected(next, editingState);
      } else if (next is VenuePickerInitial &&
          previous is VenuePickerSelected) {
        // clearSelection() was called — clear the venue fields from the draft.
        _onVenueCleared();
      }
    });

    final pickerState = ref.watch(venuePickerControllerProvider);
    final pickerController = ref.read(venuePickerControllerProvider.notifier);

    final createEventState = ref.watch(createEventControllerProvider);
    final draft = createEventState is CreateEventEditing
        ? createEventState.formData
        : const EventDraft();

    final isQuotaDegraded = pickerState is VenuePickerDegradedQuota;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search field — always visible.
        PlaceSearchField(
          controller: _searchController,
          enabled: !isQuotaDegraded,
          onChanged: pickerController.onQueryChanged,
          onCleared: () {
            _searchController.clear();
            pickerController.onQueryChanged('');
          },
        ),

        const SizedBox(height: 12),

        // Body — switches on picker state.
        _buildBody(context, pickerState, pickerController, draft),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    VenuePickerState pickerState,
    VenuePickerController pickerController,
    EventDraft draft,
  ) {
    return switch (pickerState) {
      VenuePickerInitial() => _buildInitialBody(draft),
      VenuePickerSearching() => _buildSearchingBody(),
      VenuePickerResults(:final suggestions) => _buildResultsBody(
        context,
        suggestions,
        pickerController,
        draft,
      ),
      VenuePickerEmpty(:final query) => _buildEmptyBody(context, query, draft),
      VenuePickerSelected(:final details) => _buildSelectedBody(
        context,
        details,
        pickerController,
      ),
      VenuePickerDegradedQuota() => _buildDegradedQuotaBody(context, draft),
      VenuePickerDegradedNetwork(:final message) => _buildDegradedNetworkBody(
        context,
        message,
        draft,
      ),
      VenuePickerNoCoords() => _buildNoCoordsBody(context, draft),
    };
  }

  // -----------------------------------------------------------------
  // Per-state body builders
  // -----------------------------------------------------------------

  Widget _buildInitialBody(EventDraft draft) {
    return _FreeTextSection(draft: draft, onChanged: _onFreeTextChanged);
  }

  Widget _buildSearchingBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(_kSkeletonRowCount, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i < _kSkeletonRowCount - 1 ? 8 : 0),
          child: const SkeletonLoader(
            width: double.infinity,
            height: _kSkeletonRowHeight,
            borderRadius: 8,
          ),
        );
      }),
    );
  }

  Widget _buildResultsBody(
    BuildContext context,
    List<PlaceSuggestion> suggestions,
    VenuePickerController pickerController,
    EventDraft draft,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = dark
        ? TribelyColors.nightAccent
        : TribelyColors.paperAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Suggestion rows.
        ...suggestions.map(
          (suggestion) => PlaceResultRow(
            key: ValueKey<String>(suggestion.providerPlaceId),
            name: suggestion.name,
            placeFormatted: suggestion.placeFormatted,
            onTap: () => pickerController.selectSuggestion(suggestion),
          ),
        ),

        const SizedBox(height: 12),

        // "Enter venue name manually" link — always visible in Results state.
        GestureDetector(
          onTap: () {
            // Smooth-scroll to the bottom of the enclosing SingleChildScrollView
            // (managed by Step 2 page) by sending focus to the free-text field.
            // A direct jump-to-anchor requires coordinating with the outer scroll
            // controller, which is owned by the Step 2 page. Instead we use a
            // GlobalKey on the free-text section to ensure visibility.
            Scrollable.ensureVisible(
              _freeTextKey.currentContext!,
              alignment: 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
          child: Text(
            'Enter venue name manually',
            style: TribelyType.bodyM(
              accentColor,
            ).copyWith(decoration: TextDecoration.underline),
          ),
        ),

        const SizedBox(height: 16),

        // Free-text section — always available in Results state.
        _FreeTextSection(
          key: _freeTextKey,
          draft: draft,
          onChanged: _onFreeTextChanged,
        ),
      ],
    );
  }

  Widget _buildEmptyBody(BuildContext context, String query, EventDraft draft) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _kEmptyPrimary,
          style: TribelyType.bodyM(
            inkSecondary,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(_kEmptySecondary, style: TribelyType.caption(inkSecondary)),
        const SizedBox(height: 16),
        _FreeTextSection(draft: draft, onChanged: _onFreeTextChanged),
      ],
    );
  }

  Widget _buildSelectedBody(
    BuildContext context,
    PlaceDetails details,
    VenuePickerController pickerController,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = dark
        ? TribelyColors.nightAccent
        : TribelyColors.paperAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaticMapPreview(
          latitude: details.latitude,
          longitude: details.longitude,
          venueName: details.name,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            _searchController.clear();
            pickerController.clearSelection();
          },
          child: Text(
            'Change venue',
            style: TribelyType.bodyM(
              accentColor,
            ).copyWith(decoration: TextDecoration.underline),
          ),
        ),
        // Free-text section is intentionally hidden in Selected state per
        // designer spec (brief F).
      ],
    );
  }

  Widget _buildDegradedQuotaBody(BuildContext context, EventDraft draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BannerMessage(message: _kQuotaCopy),
        const SizedBox(height: 16),
        _FreeTextSection(draft: draft, onChanged: _onFreeTextChanged),
      ],
    );
  }

  Widget _buildDegradedNetworkBody(
    BuildContext context,
    String message,
    EventDraft draft,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BannerMessage(message: message),
        const SizedBox(height: 16),
        _FreeTextSection(draft: draft, onChanged: _onFreeTextChanged),
      ],
    );
  }

  Widget _buildNoCoordsBody(BuildContext context, EventDraft draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BannerMessage(message: _kNoCoordsCopy),
        const SizedBox(height: 16),
        _FreeTextSection(draft: draft, onChanged: _onFreeTextChanged),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// GlobalKey for free-text section scroll-into-view from Results state link.
// Defined as a package-private top-level so it survives hot reload without
// being re-created on every build. The key is re-used across state transitions
// because _FreeTextSection is created with a stable identity.
// ---------------------------------------------------------------------------
final GlobalKey _freeTextKey = GlobalKey();

// ---------------------------------------------------------------------------
// Private sub-widget: free-text section wrapper
// ---------------------------------------------------------------------------

/// Wraps [FreeTextDisambiguationField] with consistent top-spacing.
///
/// Keeps the free-text field's [GlobalKey] stable across state transitions
/// so [Scrollable.ensureVisible] can locate it reliably from the Results
/// state's "Enter venue name manually" link.
class _FreeTextSection extends StatelessWidget {
  const _FreeTextSection({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final EventDraft draft;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FreeTextDisambiguationField(
      value: draft.venueDisplayNameOverride,
      onChanged: onChanged,
    );
  }
}
