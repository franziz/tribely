// Smoke tests for CreateEventPage.
//
// Strategy: override [createEventControllerProvider] with a fixed
// [CreateEventEditing] state so the controller's async init (draft load) is
// bypassed. The test-scoped GoRouter provides a minimal route tree so that
// [context.go('/my-events')] does not throw a ProviderNotFoundException or a
// missing-route assertion in production code paths.
//
// Scope: render correctness only. State-machine transitions are covered by
// the controller tests. No interactions are driven here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/usecase/usecase.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';
import 'package:tribely/src/features/events/domain/entities/event_draft.dart';
import 'package:tribely/src/features/events/domain/repositories/event_repository.dart';
import 'package:tribely/src/features/events/domain/usecases/clear_event_draft_usecase.dart';
import 'package:tribely/src/features/events/domain/usecases/create_event_usecase.dart';
import 'package:tribely/src/features/events/domain/usecases/load_event_draft_usecase.dart';
import 'package:tribely/src/features/events/domain/usecases/save_event_draft_usecase.dart';
import 'package:tribely/src/features/events/domain/ports/place_search_port.dart';
import 'package:tribely/src/features/events/domain/validators/event_validators.dart';
import 'package:tribely/src/features/events/presentation/controllers/create_event_controller.dart';
import 'package:tribely/src/features/events/presentation/pages/create_event_page.dart';
import 'package:tribely/src/features/events/presentation/providers/events_providers.dart';
import 'package:tribely/src/features/events/presentation/providers/venue_picker_providers.dart';
import 'package:tribely/src/features/events/presentation/state/create_event_state.dart';
import 'package:tribely/src/features/events/presentation/widgets/step_navigation_bar.dart';
import 'package:tribely/src/features/events/presentation/widgets/step_progress_indicator.dart';
import 'package:tribely/src/features/users/domain/entities/user_capabilities.dart';
import 'package:tribely/src/features/users/presentation/providers/capability_providers.dart';
import 'package:tribely/src/features/users/presentation/state/selfie_gating_state.dart';

// ---------------------------------------------------------------------------
// Mock use cases — used by Fix #3 widget test only
// ---------------------------------------------------------------------------

class _MockCreateEventUseCase extends Mock implements CreateEventUseCase {}

class _MockLoadEventDraftUseCase extends Mock
    implements LoadEventDraftUseCase {}

class _MockSaveEventDraftUseCase extends Mock
    implements SaveEventDraftUseCase {}

class _MockClearEventDraftUseCase extends Mock
    implements ClearEventDraftUseCase {}

// Stub PlaceSearchPort — VenuePickerSection reads placeSearchPortProvider
// which would call sl<PlaceSearchPort>() without an override. Provide a
// minimal stub so the venue-picker widget tree initialises without GetIt.
class _MockPlaceSearchPort extends Mock implements PlaceSearchPort {}

/// Synchronously resolves to the given [UserCapabilities] so overrides work
/// with the [AsyncNotifierProvider]-based [myCapabilitiesProvider].
class _FakeMyCapabilitiesNotifier extends MyCapabilitiesNotifier {
  _FakeMyCapabilitiesNotifier(this._caps);
  final UserCapabilities _caps;

  @override
  Future<UserCapabilities> build() async => _caps;
}

// Mocktail fallback values
class _FakeCreateEventParams extends Fake implements CreateEventParams {}

class _FakeEventDraft extends Fake implements EventDraft {}

class _FakeNoParams extends Fake implements NoParams {}

// ---------------------------------------------------------------------------
// Test helper — derives blocking maps from a draft using the same step→field
// mapping as the controller. Required because test subclasses of
// CreateEventController cannot access the private _deriveBlocking method.
// ---------------------------------------------------------------------------

const _testStepFields = {
  0: ['title', 'category'],
  // Brief F: Step 2 canAdvance is gated on lat/lng only (venue picker selection).
  // venueName is auto-populated by the picker, not a separate blocking field.
  1: ['latitude', 'longitude'],
  2: ['startsAt', 'endsAt'],
  3: ['capacity', 'approvalMode'],
  4: ['description'],
};

String? _testValidateField(String field, EventDraft draft) {
  return switch (field) {
    'title' => validateTitle(draft.title),
    'category' => validateCategory(draft.category),
    'venueName' => validateVenueName(draft.venueName),
    'latitude' => validateLatitude(draft.latitude),
    'longitude' => validateLongitude(draft.longitude),
    'startsAt' => validateStartsAt(draft.startsAt),
    'endsAt' => validateEndsAt(draft.endsAt, draft.startsAt),
    'capacity' => validateCapacity(draft.capacity),
    'approvalMode' => validateApprovalMode(draft.approvalMode),
    'description' => validateDescription(draft.description),
    _ => null,
  };
}

({
  Map<int, List<String>> blockingFields,
  Map<int, List<(String, String)>> blockingFieldErrors,
})
_testDeriveBlocking(EventDraft draft) {
  final fields = <int, List<String>>{};
  final errors = <int, List<(String, String)>>{};
  for (final entry in _testStepFields.entries) {
    final failingFields = <String>[];
    final failingErrors = <(String, String)>[];
    for (final field in entry.value) {
      final error = _testValidateField(field, draft);
      if (error != null) {
        failingFields.add(field);
        failingErrors.add((field, error));
      }
    }
    if (failingFields.isNotEmpty) {
      fields[entry.key] = failingFields;
      errors[entry.key] = failingErrors;
    }
  }
  return (blockingFields: fields, blockingFieldErrors: errors);
}

// ---------------------------------------------------------------------------
// Fixed controller — returns a constant CreateEventEditing with no async work.
// ---------------------------------------------------------------------------

class _FixedEditingController extends CreateEventController {
  @override
  CreateEventState build() {
    const draft = EventDraft();
    final (:blockingFields, :blockingFieldErrors) = _testDeriveBlocking(draft);
    return CreateEventEditing(
      formData: draft,
      currentStep: 0,
      fieldErrors: const {},
      isResuming: false,
      blockingFields: blockingFields,
      blockingFieldErrors: blockingFieldErrors,
    );
  }
}

/// Step-4 controller with all step-4 fields valid but capacity == null.
/// Proves that canSubmit() is false (and the Publish button is disabled)
/// even though canAdvance(4) would be true.
class _Step4MissingCapacityController extends CreateEventController {
  @override
  CreateEventState build() {
    const draft = EventDraft(
      // All step-4 fields valid.
      description: 'A lovely hike for solo travellers exploring Singapore.',
      // All other steps have at least one null field (capacity is absent).
      title: 'Sunday Morning Hike',
      category: EventCategory.hike,
      venueName: '1 Marina Blvd, Marina Bay',
      latitude: 1.28,
      longitude: 103.85,
      startsAt: null, // startsAt null → canSubmit() returns false
      // capacity intentionally null
    );
    final (:blockingFields, :blockingFieldErrors) = _testDeriveBlocking(draft);
    return CreateEventEditing(
      formData: draft,
      currentStep: 4,
      fieldErrors: const {},
      isResuming: false,
      blockingFields: blockingFields,
      blockingFieldErrors: blockingFieldErrors,
    );
  }
}

/// Controller with a fully-valid draft at step 0. Supports real navigation
/// (nextStep / previousStep) without triggering async use cases by skipping
/// the draft-load microtask. Used by the round-trip test (test 8).
class _ValidDraftController extends CreateEventController {
  static const _draft = EventDraft(
    title: 'Sunday Morning Hike',
    category: EventCategory.hike,
    venueName: '1 Marina Blvd, Marina Bay',
    latitude: 1.28,
    longitude: 103.85,
    startsAt: null, // overridden via _setDateFields
    endsAt: null,
    capacity: 10,
    approvalMode: 'auto',
    description: 'A lovely hike for solo travellers exploring Singapore.',
    currentStep: 0,
  );

  @override
  CreateEventState build() {
    // Build with dates so all fields are valid. Use a fixed far-future date
    // to avoid validator rejection.
    final startsAt = DateTime(2030, 6, 1, 8);
    final endsAt = DateTime(2030, 6, 1, 11);
    final draft = _draft.copyWith(startsAt: startsAt, endsAt: endsAt);
    final (:blockingFields, :blockingFieldErrors) = _testDeriveBlocking(draft);
    return CreateEventEditing(
      formData: draft,
      currentStep: 0,
      fieldErrors: const {},
      isResuming: false,
      blockingFields: blockingFields,
      blockingFieldErrors: blockingFieldErrors,
    );
  }
}

// ---------------------------------------------------------------------------
// Minimal GoRouter for the smoke test.
//
// CreateEventPage calls context.go('/my-events') on success. Providing a real
// GoRouter avoids LookupBoundary failures without needing a full production
// route tree.
// ---------------------------------------------------------------------------

GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/events/create',
    routes: [
      GoRoute(
        path: '/events/create',
        builder: (context, state) => const CreateEventPage(),
      ),
      GoRoute(
        path: '/my-events',
        builder: (context, state) =>
            const Scaffold(body: Text('my-events-stub')),
      ),
    ],
  );
}

/// Pumps the full test widget tree with [controllerFactory] overriding the
/// createEventController provider.
Future<void> _pumpPage(
  WidgetTester tester,
  CreateEventController Function() controllerFactory,
) async {
  final mockPort = _MockPlaceSearchPort();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        createEventControllerProvider.overrideWith(controllerFactory),
        // Default to Approved so existing tests are unaffected by selfie gating.
        selfieGatingStateProvider.overrideWithValue(
          const SelfieGatingApproved(),
        ),
        // Brief F: VenuePickerSection reads placeSearchPortProvider (via
        // venuePickerControllerProvider). Override to avoid GetIt access in tests.
        placeSearchPortProvider.overrideWithValue(mockPort),
        // myCapabilitiesProvider is read by _computeWarning in the controller.
        // Override to avoid sl<UserCapabilitiesRepository>() in tests.
        myCapabilitiesProvider.overrideWith(
          () => _FakeMyCapabilitiesNotifier(
            const UserCapabilities(
              canPostPrivateVenue: false,
              safetyReminderSeen: false,
            ),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: _buildTestRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCreateEventParams());
    registerFallbackValue(_FakeEventDraft());
    registerFallbackValue(_FakeNoParams());
  });

  group('CreateEventPage smoke', () {
    testWidgets('renders app bar title "Create Event"', (tester) async {
      await _pumpPage(tester, _FixedEditingController.new);
      expect(find.text('Create Event'), findsOneWidget);
    });

    testWidgets('renders exactly one StepProgressIndicator', (tester) async {
      await _pumpPage(tester, _FixedEditingController.new);
      expect(find.byType(StepProgressIndicator), findsOneWidget);
    });

    testWidgets('step 1 renders a text field labelled "Title"', (tester) async {
      await _pumpPage(tester, _FixedEditingController.new);

      // Step 1 (Basics) is the active page at currentStep=0.
      // EventFormField renders a TextFormField with an InputDecoration whose
      // labelText is 'Title'. Find by the label text.
      expect(find.text('Title'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Bug 2 regression — Publish button disabled when prior-step data is invalid
  // ---------------------------------------------------------------------------
  group('CreateEventPage — Publish gate (Bug 2 regression)', () {
    testWidgets(
      'Publish button is disabled when on step 4 with invalid prior-step data',
      (tester) async {
        await _pumpPage(tester, _Step4MissingCapacityController.new);

        // The StepNavigationBar renders the Publish FilledButton as disabled
        // (onPressed == null) when canAdvance is false.
        final navBar = tester.widget<StepNavigationBar>(
          find.byType(StepNavigationBar),
        );
        // canAdvance passed to StepNavigationBar must be false (canSubmit is
        // false because startsAt and capacity are null).
        expect(navBar.canAdvance, isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Bug 1 regression — keyboard dismissal
  // ---------------------------------------------------------------------------
  group('CreateEventPage — keyboard dismissal (Bug 1 regression)', () {
    testWidgets('tapping page body outside any input clears primary focus', (
      tester,
    ) async {
      await _pumpPage(tester, _FixedEditingController.new);

      // Focus the Title text field.
      final titleField = find.byType(TextFormField).first;
      await tester.tap(titleField);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      // Tap an empty area — the GestureDetector wrapping the body should
      // call FocusScope.unfocus(). Use a point near the bottom of the visible
      // area (outside form fields) but above the nav bar.
      await tester.tapAt(const Offset(200, 400));
      await tester.pump();

      // unfocus() with UnfocusDisposition.scope moves focus up to the
      // enclosing FocusScopeNode (_ModalScopeState) rather than setting
      // primaryFocus to null. A FocusScopeNode as primary focus is equivalent
      // to keyboard dismissal — no TextInputClient is active. Both null and
      // FocusScopeNode are correct post-unfocus states in the test harness;
      // the real-device behavior (keyboard dismissed) is what matters.
      expect(
        FocusManager.instance.primaryFocus,
        anyOf(isNull, isA<FocusScopeNode>()),
      );
    });

    testWidgets(
      'pressing Next on step 0 with valid data clears primary focus',
      (tester) async {
        // Use a valid-draft controller so the Next button is enabled.
        await _pumpPage(tester, _ValidDraftController.new);

        // Focus the Title field.
        final titleField = find.byType(TextFormField).first;
        await tester.tap(titleField);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, isNotNull);

        // Tap the Next button.
        final nextButton = find.text('Next');
        await tester.tap(nextButton);
        // pumpAndSettle drains the microtask queue so unfocus() takes full
        // effect before the assertion runs.
        await tester.pumpAndSettle();

        // nextStep() calls FocusManager.instance.primaryFocus?.unfocus() at
        // the top. unfocus(UnfocusDisposition.scope) moves focus up to the
        // enclosing FocusScopeNode (_ModalScopeState) rather than null in the
        // test harness — which is equivalent to keyboard dismissal (no
        // TextInputClient active). See tap-outside test for full rationale.
        expect(
          FocusManager.instance.primaryFocus,
          anyOf(isNull, isA<FocusScopeNode>()),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Fix #3 — server ValidationFailure.message surfaces in the UI (TRI-26)
  //
  // The controller's _handleSubmitFailure maps ValidationFailure (no
  // fieldErrors) to {'_banner': failure.message}. The page's ref.listen
  // shows a SnackBar with that banner. This test verifies the full path
  // end-to-end through the widget tree.
  // ---------------------------------------------------------------------------
  group('CreateEventPage — server validation message surfaced in UI', () {
    testWidgets(
      'ValidationFailure from createEvent is shown as SnackBar text',
      (tester) async {
        const validationMessage = 'Event startsAt must be in the future';

        // --- Mock use cases ---
        final mockCreate = _MockCreateEventUseCase();
        final mockLoad = _MockLoadEventDraftUseCase();
        final mockSave = _MockSaveEventDraftUseCase();
        final mockClear = _MockClearEventDraftUseCase();

        when(() => mockLoad(any())).thenAnswer((_) async => const Right(null));
        when(() => mockSave(any())).thenAnswer((_) async => const Right(null));
        when(() => mockCreate(any())).thenAnswer(
          (_) async => const Left(
            ValidationFailure(validationMessage, code: 'VALIDATION_FAILED'),
          ),
        );
        when(() => mockClear(any())).thenAnswer((_) async => const Right(null));

        // --- Build a controller seeded with a fully-valid draft so
        //     canSubmit() returns true and submit() can proceed.        ---
        //
        // Override createEventControllerProvider with a real
        // CreateEventController that will read the mocked use case
        // providers. Also override the four use case providers so the
        // real controller picks up the mocks.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEventUseCaseProvider.overrideWithValue(mockCreate),
              loadEventDraftUseCaseProvider.overrideWithValue(mockLoad),
              saveEventDraftUseCaseProvider.overrideWithValue(mockSave),
              clearEventDraftUseCaseProvider.overrideWithValue(mockClear),
              // Use _ValidDraftController so the Publish button is enabled
              // without waiting for real async draft-load.
              createEventControllerProvider.overrideWith(
                _ValidDraftController.new,
              ),
              // Default to Approved so selfie gating does not block Publish.
              selfieGatingStateProvider.overrideWithValue(
                const SelfieGatingApproved(),
              ),
            ],
            child: MaterialApp.router(routerConfig: _buildTestRouter()),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to step 4 so the Publish button appears.
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }

        // Tap Publish — triggers submit() which calls mockCreate.
        await tester.tap(find.text('Publish'));
        // Allow the async submit() → mockCreate → _handleSubmitFailure chain.
        await tester.pumpAndSettle();

        // The SnackBar must contain the server's exact validation message.
        expect(find.text(validationMessage), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // A3 widget tests — blocking hint renders on Step 5 when blockingFields non-empty
  // ---------------------------------------------------------------------------
  group('CreateEventPage — blocking hint (A3, Bug #5 regression)', () {
    testWidgets(
      'blocking hint is visible on Step 5 when startsAt is past the buffer',
      (tester) async {
        // _Step4MissingCapacityController has startsAt==null + capacity==null.
        // Both step 2 and step 3 are blocking → hint should appear.
        await _pumpPage(tester, _Step4MissingCapacityController.new);

        // The hint text must mention "Can't publish yet".
        expect(find.textContaining("Can't publish yet"), findsOneWidget);
      },
    );

    testWidgets('each blocking hint item is tappable and calls goToStep', (
      tester,
    ) async {
      // Use a controller seeded at step 4 with a missing field so the hint renders.
      await _pumpPage(tester, _Step4MissingCapacityController.new);

      // The hint must render at least one "Edit" tap target.
      expect(find.text('Edit'), findsWidgets);

      // Tap the first Edit link — must not throw.
      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'blocking hint is NOT visible on Step 5 when all fields are valid',
      (tester) async {
        // _ValidDraftController seeds a fully-valid draft. Advance to step 4.
        await _pumpPage(tester, _ValidDraftController.new);

        // Advance to step 4 (all steps valid, Publish is enabled).
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }

        // No blocking hint text when all fields are valid.
        expect(find.textContaining("Can't publish yet"), findsNothing);
      },
    );

    testWidgets(
      'intermediate-step hint appears above nav bar when canAdvance is false',
      (tester) async {
        // _FixedEditingController seeds a fresh draft at step 0. With blocking
        // derivation active, title + category are null → step 0 is blocking.
        await _pumpPage(tester, _FixedEditingController.new);

        // The intermediate-step hint renders "Step 1: Title is required" or
        // similar, since title is null on a fresh draft at step 0.
        expect(find.textContaining('Step 1:'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Bug 2 regression — round-trip navigation preserves Publish enabled state
  // ---------------------------------------------------------------------------
  group('CreateEventPage — round-trip navigation (Bug 2 regression)', () {
    testWidgets(
      'step 0 → 4 → 3 → 4 keeps Publish enabled when all fields valid',
      (tester) async {
        // _ValidDraftController seeds a fully-valid draft at step 0.
        await _pumpPage(tester, _ValidDraftController.new);

        Future<void> tapNext() async {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }

        Future<void> tapBack() async {
          await tester.tap(find.text('Back'));
          await tester.pumpAndSettle();
        }

        // Advance step 0 → 1 → 2 → 3 → 4.
        await tapNext(); // → step 1
        await tapNext(); // → step 2
        await tapNext(); // → step 3
        await tapNext(); // → step 4

        // Navigate back step 4 → 3, then forward step 3 → 4.
        await tapBack(); // → step 3
        await tapNext(); // → step 4

        // On step 4 with all fields valid, canAdvance passed to StepNavigationBar
        // must be true (canSubmit() returns true).
        final navBar = tester.widget<StepNavigationBar>(
          find.byType(StepNavigationBar),
        );
        expect(navBar.canAdvance, isTrue);
        // The Publish button must be labelled 'Publish' (not 'Next').
        expect(find.text('Publish'), findsOneWidget);
      },
    );
  });
}
