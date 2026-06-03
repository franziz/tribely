// Widget tests for VenuePickerSection.
//
// Strategy: override both [venuePickerControllerProvider] and
// [createEventControllerProvider] with fixed states / mock notifiers so no
// real async work (draft load, network calls, GetIt) is triggered.
//
// Covered states (per EL brief F):
//   1. Initial  — search field visible, no result list, no static map,
//                 free-text section visible.
//   2. Searching → Results — tapping a row calls selectSuggestion on the
//                 controller; rows render the correct name + placeFormatted.
//   3. Empty    — empty-state copy verbatim.
//   4. Selected — StaticMapPreview visible, "Change venue" link visible,
//                 result list hidden, free-text section hidden.
//   5. DegradedQuota — search field disabled, banner with quota copy verbatim,
//                 free-text section visible.
//   6. DegradedNetwork — banner with provided message; search field stays enabled.
//   7. NoCoords — banner with no-coords copy verbatim, free-text section visible.
//   8. EventDraft write side-effect — venueDisplayNameOverride updated when
//                 free-text field changes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/widgets/place_result_row.dart';
import 'package:tribely/src/features/events/domain/entities/event_draft.dart';
import 'package:tribely/src/features/events/domain/entities/place_details.dart';
import 'package:tribely/src/features/events/domain/entities/place_suggestion.dart';
import 'package:tribely/src/features/events/domain/ports/place_search_port.dart';
import 'package:tribely/src/features/events/domain/usecases/save_event_draft_usecase.dart';
import 'package:tribely/src/features/events/presentation/controllers/create_event_controller.dart';
import 'package:tribely/src/features/events/presentation/controllers/venue_picker_controller.dart';
import 'package:tribely/src/features/events/presentation/providers/events_providers.dart';
import 'package:tribely/src/features/events/presentation/providers/venue_picker_providers.dart';
import 'package:tribely/src/features/events/presentation/state/create_event_state.dart';
import 'package:tribely/src/features/events/presentation/state/venue_picker_state.dart';
import 'package:tribely/src/features/events/presentation/widgets/static_map_preview.dart';
import 'package:tribely/src/features/events/presentation/widgets/venue_picker_section.dart';
import 'package:tribely/src/features/users/domain/entities/user_capabilities.dart';
import 'package:tribely/src/features/users/presentation/providers/capability_providers.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockPlaceSearchPort extends Mock implements PlaceSearchPort {}

class _MockSaveEventDraftUseCase extends Mock
    implements SaveEventDraftUseCase {}

// ---------------------------------------------------------------------------
// Fixed venue-picker controller stubs
//
// Each stub forces a specific [VenuePickerState] by overriding [build].
// Spy state is injected via constructor callbacks so no public properties
// live on the Notifier (avoids avoid_public_notifier_properties lint).
// ---------------------------------------------------------------------------

class _FixedInitialController extends VenuePickerController {
  @override
  VenuePickerState build() => const VenuePickerInitial();
}

class _FixedResultsController extends VenuePickerController {
  /// [onSelectSuggestion] is called with each [PlaceSuggestion] passed to
  /// [selectSuggestion], letting tests capture calls without a public field.
  _FixedResultsController({this.onSelectSuggestion});
  final void Function(PlaceSuggestion)? onSelectSuggestion;

  @override
  VenuePickerState build() =>
      const VenuePickerResults([_suggestion1, _suggestion2]);

  @override
  Future<void> selectSuggestion(PlaceSuggestion suggestion) async {
    onSelectSuggestion?.call(suggestion);
    state = VenuePickerSelected(
      PlaceDetails(
        providerPlaceId: suggestion.providerPlaceId,
        name: suggestion.name,
        formattedAddress: suggestion.placeFormatted,
        latitude: 1.28,
        longitude: 103.85,
      ),
    );
  }
}

class _FixedEmptyController extends VenuePickerController {
  @override
  VenuePickerState build() => const VenuePickerEmpty('random-query');
}

class _FixedSelectedController extends VenuePickerController {
  /// [onClearSelection] is invoked when [clearSelection] is called,
  /// letting tests assert the call without a public boolean field.
  _FixedSelectedController({this.onClearSelection});
  final void Function()? onClearSelection;

  @override
  VenuePickerState build() => const VenuePickerSelected(
    PlaceDetails(
      providerPlaceId: 'mapbox-1',
      name: 'Lau Pa Sat',
      formattedAddress: '18 Raffles Quay, Singapore 048582',
      latitude: 1.2841,
      longitude: 103.8504,
    ),
  );

  @override
  void clearSelection() {
    onClearSelection?.call();
    state = const VenuePickerInitial();
  }
}

class _FixedDegradedQuotaController extends VenuePickerController {
  @override
  VenuePickerState build() => const VenuePickerDegradedQuota();
}

class _FixedDegradedNetworkController extends VenuePickerController {
  @override
  VenuePickerState build() =>
      const VenuePickerDegradedNetwork('Check your connection and try again.');
}

class _FixedNoCoordsController extends VenuePickerController {
  @override
  VenuePickerState build() => const VenuePickerNoCoords('Mapbox');
}

// ---------------------------------------------------------------------------
// Fixed create-event controller stub
//
// Overrides [build] to return a [CreateEventEditing] with a fresh [EventDraft]
// without triggering the async draft-load microtask.
//
// [onUpdateVenueDisplayNameOverride] is called with each value passed to
// [updateVenueDisplayNameOverride], letting tests capture calls via a
// test-local variable rather than a public Notifier property.
// ---------------------------------------------------------------------------

class _FixedCreateController extends CreateEventController {
  _FixedCreateController({this.onUpdateVenueDisplayNameOverride});
  final void Function(String?)? onUpdateVenueDisplayNameOverride;

  @override
  CreateEventState build() {
    return const CreateEventEditing(
      formData: EventDraft(),
      currentStep: 1,
      fieldErrors: {},
      isResuming: false,
      blockingFields: {
        1: ['latitude', 'longitude'],
      },
      blockingFieldErrors: {
        1: [('latitude', 'Latitude is required')],
      },
    );
  }

  @override
  void updateVenueDisplayNameOverride(String? value) {
    onUpdateVenueDisplayNameOverride?.call(value);
    // Also update state so the free-text field reflects the change.
    final current = state;
    if (current is! CreateEventEditing) return;
    if (value == null) {
      final d = current.formData;
      final cleared = EventDraft(
        title: d.title,
        category: d.category,
        venueName: d.venueName,
        venueCategory: d.venueCategory,
        latitude: d.latitude,
        longitude: d.longitude,
        startsAt: d.startsAt,
        endsAt: d.endsAt,
        capacity: d.capacity,
        costNotes: d.costNotes,
        approvalMode: d.approvalMode,
        description: d.description,
        currentStep: d.currentStep,
        lastUpdatedAt: d.lastUpdatedAt,
        providerPlaceId: d.providerPlaceId,
        venueAddress: d.venueAddress,
        rawProviderCategory: d.rawProviderCategory,
        venueDisplayNameOverride: null,
      );
      state = current.copyWith(formData: cleared);
    } else {
      state = current.copyWith(
        formData: current.formData.copyWith(venueDisplayNameOverride: value),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Fixture data
// ---------------------------------------------------------------------------

const _suggestion1 = PlaceSuggestion(
  providerPlaceId: 'mapbox-1',
  name: 'Lau Pa Sat',
  placeFormatted: '18 Raffles Quay, Singapore 048582',
);

const _suggestion2 = PlaceSuggestion(
  providerPlaceId: 'mapbox-2',
  name: 'Marina Bay Sands',
  placeFormatted: '10 Bayfront Ave, Singapore 018956',
);

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

/// Builds a [ProviderScope] with all required overrides and pumps
/// [VenuePickerSection] inside a [Scaffold] / [MaterialApp].
///
/// [pickerFactory] — factory for [VenuePickerController] stub.
/// [createFactory] — factory for [CreateEventController] stub (defaults to
///   [_FixedCreateController]).
Future<void> _pump(
  WidgetTester tester, {
  required VenuePickerController Function() pickerFactory,
  CreateEventController Function()? createFactory,
}) async {
  final mockPort = _MockPlaceSearchPort();
  final mockSaveUseCase = _MockSaveEventDraftUseCase();
  when(
    () => mockSaveUseCase.call(any()),
  ).thenAnswer((_) async => const Right(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        placeSearchPortProvider.overrideWithValue(mockPort),
        saveEventDraftUseCaseProvider.overrideWithValue(mockSaveUseCase),
        venuePickerControllerProvider.overrideWith(pickerFactory),
        createEventControllerProvider.overrideWith(
          createFactory ?? _FixedCreateController.new,
        ),
        myCapabilitiesProvider.overrideWith(
          (_) async => const UserCapabilities(
            canPostPrivateVenue: false,
            safetyReminderSeen: false,
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: VenuePickerSection(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(const EventDraft());
  });

  // -------------------------------------------------------------------------
  // 1. Initial state
  // -------------------------------------------------------------------------
  group('VenuePickerSection — Initial state', () {
    testWidgets('search field is visible, no result rows, no StaticMapPreview, '
        'free-text section visible', (tester) async {
      await _pump(tester, pickerFactory: _FixedInitialController.new);

      // Search field present (PlaceSearchField renders a TextField).
      expect(find.byType(TextField), findsWidgets);

      // No suggestion rows.
      expect(find.byType(PlaceResultRow), findsNothing);

      // StaticMapPreview not present.
      expect(find.byType(StaticMapPreview), findsNothing);

      // Free-text section heading is visible.
      expect(find.text("Can't find it? Enter the venue name"), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Results state — tapping a row calls selectSuggestion
  // -------------------------------------------------------------------------
  group('VenuePickerSection — Results state', () {
    testWidgets('rows render with correct name and placeFormatted; '
        'tapping first row calls selectSuggestion', (tester) async {
      final calledWith = <PlaceSuggestion>[];
      final pickerController = _FixedResultsController(
        onSelectSuggestion: calledWith.add,
      );

      await _pump(tester, pickerFactory: () => pickerController);

      // Both suggestion names are visible.
      expect(find.text('Lau Pa Sat'), findsOneWidget);
      expect(find.text('18 Raffles Quay, Singapore 048582'), findsOneWidget);
      expect(find.text('Marina Bay Sands'), findsOneWidget);
      expect(find.text('10 Bayfront Ave, Singapore 018956'), findsOneWidget);

      // Tap the first row.
      await tester.tap(find.text('Lau Pa Sat'));
      await tester.pumpAndSettle();
      // Drain the 500 ms autosave timer scheduled by updateField /
      // applyVenueDetails inside _onVenueSelected.
      await tester.pump(const Duration(milliseconds: 500));

      // selectSuggestion was called with the first suggestion.
      expect(calledWith, hasLength(1));
      expect(calledWith.first.providerPlaceId, equals('mapbox-1'));
      expect(calledWith.first.name, equals('Lau Pa Sat'));
      expect(
        calledWith.first.placeFormatted,
        equals('18 Raffles Quay, Singapore 048582'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3. Empty state — copy verbatim
  // -------------------------------------------------------------------------
  group('VenuePickerSection — Empty state', () {
    testWidgets('renders empty-state copy verbatim', (tester) async {
      await _pump(tester, pickerFactory: _FixedEmptyController.new);

      expect(find.text('No matches in Singapore.'), findsOneWidget);
      expect(
        find.text(
          'Try a different name, or enter a venue name manually below.',
        ),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 4. Selected state
  // -------------------------------------------------------------------------
  group('VenuePickerSection — Selected state', () {
    testWidgets('StaticMapPreview visible, "Change venue" link visible, '
        'result list hidden, free-text section hidden', (tester) async {
      await _pump(tester, pickerFactory: _FixedSelectedController.new);

      // StaticMapPreview present.
      expect(find.byType(StaticMapPreview), findsOneWidget);

      // "Change venue" link.
      expect(find.text('Change venue'), findsOneWidget);

      // No suggestion rows — use the widget type, not text, because
      // StaticMapPreview also renders the venue name as Text labels.
      expect(find.byType(PlaceResultRow), findsNothing);

      // Free-text section heading NOT visible.
      expect(find.text("Can't find it? Enter the venue name"), findsNothing);
    });

    testWidgets(
      '"Change venue" tap calls clearSelection on picker controller',
      (tester) async {
        var clearCalled = false;
        final pickerController = _FixedSelectedController(
          onClearSelection: () => clearCalled = true,
        );

        await _pump(tester, pickerFactory: () => pickerController);

        await tester.tap(find.text('Change venue'));
        // Drain the 500 ms autosave timer scheduled by clearVenueSelection
        // before the test exits — flutter_test treats pending timers as fatal.
        await tester.pump(const Duration(milliseconds: 500));

        expect(clearCalled, isTrue);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 5. DegradedQuota state
  // -------------------------------------------------------------------------
  group('VenuePickerSection — DegradedQuota state', () {
    testWidgets('search field disabled, quota banner visible verbatim, '
        'free-text section visible', (tester) async {
      await _pump(tester, pickerFactory: _FixedDegradedQuotaController.new);

      // Quota banner copy verbatim.
      expect(
        find.text(
          'Search is temporarily unavailable. Enter the venue name manually below.',
        ),
        findsOneWidget,
      );

      // Free-text section heading visible.
      expect(find.text("Can't find it? Enter the venue name"), findsOneWidget);

      // Search field is disabled — Opacity wraps it at 0.5 when disabled.
      // The TextField itself has enabled=false when quota is degraded.
      // We verify via the Opacity widget: the PlaceSearchField wraps the
      // entire widget in an Opacity(opacity: 0.5) when !enabled.
      final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
      final hasHalfOpacity = opacityWidgets.any((o) => o.opacity == 0.5);
      expect(hasHalfOpacity, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // 6. DegradedNetwork state
  // -------------------------------------------------------------------------
  group('VenuePickerSection — DegradedNetwork state', () {
    testWidgets(
      'banner visible with provided message; search field stays enabled',
      (tester) async {
        await _pump(tester, pickerFactory: _FixedDegradedNetworkController.new);

        // Network error banner shows the message from state.
        expect(
          find.text('Check your connection and try again.'),
          findsOneWidget,
        );

        // Free-text section heading visible.
        expect(
          find.text("Can't find it? Enter the venue name"),
          findsOneWidget,
        );

        // Search field is NOT disabled in DegradedNetwork — no Opacity at 0.5.
        // (DegradedQuota is the only state that disables the search field.)
        final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
        final hasHalfOpacity = opacityWidgets.any((o) => o.opacity == 0.5);
        expect(hasHalfOpacity, isFalse);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 7. NoCoords state
  // -------------------------------------------------------------------------
  group('VenuePickerSection — NoCoords state', () {
    testWidgets(
      'no-coords banner visible verbatim, free-text section visible',
      (tester) async {
        await _pump(tester, pickerFactory: _FixedNoCoordsController.new);

        // No-coords banner copy verbatim.
        expect(
          find.text(
            "This venue couldn't be located on the map. "
            'Try a different name or enter manually.',
          ),
          findsOneWidget,
        );

        // Free-text section heading visible.
        expect(
          find.text("Can't find it? Enter the venue name"),
          findsOneWidget,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // 8. EventDraft write side-effect — free-text onChanged
  // -------------------------------------------------------------------------
  group('VenuePickerSection — free-text EventDraft write', () {
    testWidgets(
      'typing in the free-text field calls updateVenueDisplayNameOverride '
      'on the create-event controller',
      (tester) async {
        String? lastOverride;
        final createController = _FixedCreateController(
          onUpdateVenueDisplayNameOverride: (v) => lastOverride = v,
        );

        await _pump(
          tester,
          pickerFactory: _FixedInitialController.new,
          createFactory: () => createController,
        );

        // Find the free-text TribelyTextField. It renders a TextField inside
        // a TribelyTextField inside FreeTextDisambiguationField.
        // The label is "e.g. Lau Pa Sat, Marina Bay Sands".
        // We enter text via the TextField widget.
        final textFields = find.byType(TextField);
        // The first TextField is the PlaceSearchField; the second (if present)
        // is the free-text TribelyTextField.
        // Tap the last TextField to focus the free-text field.
        await tester.tap(textFields.last);
        await tester.pump();
        await tester.enterText(textFields.last, 'My Venue');
        await tester.pump();

        // updateVenueDisplayNameOverride should have been called.
        expect(lastOverride, equals('My Venue'));
      },
    );

    testWidgets(
      'clearing the free-text field calls updateVenueDisplayNameOverride(null)',
      (tester) async {
        String? lastOverride;
        final createController = _FixedCreateController(
          onUpdateVenueDisplayNameOverride: (v) => lastOverride = v,
        );

        await _pump(
          tester,
          pickerFactory: _FixedInitialController.new,
          createFactory: () => createController,
        );

        // Enter text first.
        final textFields = find.byType(TextField);
        await tester.tap(textFields.last);
        await tester.pump();
        await tester.enterText(textFields.last, 'Test Name');
        await tester.pump();
        expect(lastOverride, equals('Test Name'));

        // Clear the text field.
        await tester.enterText(textFields.last, '');
        await tester.pump();

        // Should call with null on empty string.
        expect(lastOverride, isNull);
      },
    );
  });
}
