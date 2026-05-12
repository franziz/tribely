import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/usecase/usecase.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';
import 'package:tribely/src/features/events/domain/entities/event_draft.dart';
import 'package:tribely/src/features/events/domain/repositories/event_repository.dart';
import 'package:tribely/src/features/events/domain/usecases/clear_event_draft_usecase.dart';
import 'package:tribely/src/features/events/domain/usecases/create_event_usecase.dart';
import 'package:tribely/src/features/events/domain/usecases/load_event_draft_usecase.dart';
import 'package:tribely/src/features/events/domain/usecases/save_event_draft_usecase.dart';
import 'package:tribely/src/features/events/presentation/providers/events_providers.dart';
import 'package:tribely/src/features/events/presentation/state/create_event_state.dart';

// ---------------------------------------------------------------------------
// Mock use cases
// ---------------------------------------------------------------------------

class _MockCreateEventUseCase extends Mock implements CreateEventUseCase {}

class _MockLoadEventDraftUseCase extends Mock
    implements LoadEventDraftUseCase {}

class _MockSaveEventDraftUseCase extends Mock
    implements SaveEventDraftUseCase {}

class _MockClearEventDraftUseCase extends Mock
    implements ClearEventDraftUseCase {}

// ---------------------------------------------------------------------------
// Fallback registrations required by mocktail
// ---------------------------------------------------------------------------

class _FakeCreateEventParams extends Fake implements CreateEventParams {}

class _FakeEventDraft extends Fake implements EventDraft {}

class _FakeNoParams extends Fake implements NoParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal [Event] returned by a successful createEvent call.
Event _stubEvent({String id = 'evt-1'}) {
  return Event(
    id: id,
    hostId: 'usr-1',
    title: 'Test Event',
    description: 'A description',
    venue: const EventVenue(
      address: '1 Marina Blvd',
      city: 'Singapore',
      latitude: 1.28,
      longitude: 103.85,
    ),
    startsAt: DateTime(2030, 1, 1, 18),
    endsAt: DateTime(2030, 1, 1, 21),
    capacity: 10,
    category: EventCategory.drinks,
    costSplit: 'own',
    approvalMode: 'auto',
    status: 'published',
    createdAt: DateTime(2030, 1, 1),
  );
}

/// A fully-valid [EventDraft] that satisfies canAdvance(0) for step-0 tests
/// and can be submitted after all required fields are filled.
EventDraft _validDraft() {
  return EventDraft(
    title: 'Sunday Morning Hike',
    category: EventCategory.hike,
    venueName: '1 Marina Blvd, Marina Bay',
    latitude: 1.28,
    longitude: 103.85,
    startsAt: DateTime(2030, 6, 1, 8),
    endsAt: DateTime(2030, 6, 1, 11),
    capacity: 10,
    approvalMode: 'auto',
    description: 'A lovely hike for solo travellers exploring Singapore.',
    currentStep: 0,
  );
}

/// Build a [ProviderContainer] with all four use-case providers overridden.
/// Returns both the container and the mocks so callers can stub individual
/// methods.
({
  ProviderContainer container,
  _MockCreateEventUseCase create,
  _MockLoadEventDraftUseCase load,
  _MockSaveEventDraftUseCase save,
  _MockClearEventDraftUseCase clear,
})
_makeContainer() {
  final create = _MockCreateEventUseCase();
  final load = _MockLoadEventDraftUseCase();
  final save = _MockSaveEventDraftUseCase();
  final clear = _MockClearEventDraftUseCase();

  final container = ProviderContainer(
    overrides: [
      createEventUseCaseProvider.overrideWithValue(create),
      loadEventDraftUseCaseProvider.overrideWithValue(load),
      saveEventDraftUseCaseProvider.overrideWithValue(save),
      clearEventDraftUseCaseProvider.overrideWithValue(clear),
    ],
  );

  return (
    container: container,
    create: create,
    load: load,
    save: save,
    clear: clear,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCreateEventParams());
    registerFallbackValue(_FakeEventDraft());
    registerFallbackValue(_FakeNoParams());
  });

  // ---------------------------------------------------------------------------
  // Draft load on init
  // ---------------------------------------------------------------------------
  group('init — draft load', () {
    test(
      'loadDraft returns Right(null) → editing state with isResuming=false, step=0',
      () async {
        final (:container, :load, :save, :create, :clear) = _makeContainer();
        addTearDown(container.dispose);

        when(() => load(any())).thenAnswer((_) async => const Right(null));

        // Read the provider to trigger build() + the async side-effect.
        container.read(createEventControllerProvider);
        // Allow the async _loadDraftAndInit to complete.
        await Future<void>.value();

        final state = container.read(createEventControllerProvider);
        expect(state, isA<CreateEventEditing>());
        final editing = state as CreateEventEditing;
        expect(editing.isResuming, isFalse);
        expect(editing.currentStep, 0);
      },
    );

    test(
      'loadDraft returns Right(draft with step=2, title="foo") → isResuming=true, step=2, title=foo',
      () async {
        final (:container, :load, :save, :create, :clear) = _makeContainer();
        addTearDown(container.dispose);

        final draft = const EventDraft(title: 'foo', currentStep: 2);
        when(() => load(any())).thenAnswer((_) async => Right(draft));

        container.read(createEventControllerProvider);
        // Two awaits: the first lets _loadDraftAndInit start; the second lets
        // the inner `await useCase(...)` complete (the mock's async function
        // schedules one extra microtask even when it returns immediately).
        await Future<void>.value();
        await Future<void>.value();

        final state = container.read(createEventControllerProvider);
        expect(state, isA<CreateEventEditing>());
        final editing = state as CreateEventEditing;
        expect(editing.isResuming, isTrue);
        expect(editing.currentStep, 2);
        expect(editing.formData.title, 'foo');
      },
    );

    test(
      'loadDraft returns Left(UnknownFailure) → state is fresh editing (does not block)',
      () async {
        final (:container, :load, :save, :create, :clear) = _makeContainer();
        addTearDown(container.dispose);

        when(
          () => load(any()),
        ).thenAnswer((_) async => const Left(UnknownFailure('storage error')));

        container.read(createEventControllerProvider);
        await Future<void>.value();

        final state = container.read(createEventControllerProvider);
        expect(state, isA<CreateEventEditing>());
        final editing = state as CreateEventEditing;
        expect(editing.isResuming, isFalse);
        expect(editing.currentStep, 0);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // updateField
  // ---------------------------------------------------------------------------
  group('updateField', () {
    late ProviderContainer container;
    late _MockLoadEventDraftUseCase load;
    late _MockSaveEventDraftUseCase save;

    setUp(() async {
      final result = _makeContainer();
      container = result.container;
      load = result.load;
      save = result.save;

      when(() => load(any())).thenAnswer((_) async => const Right(null));
      when(() => save(any())).thenAnswer((_) async => const Right(null));

      container.read(createEventControllerProvider);
      await Future<void>.value();
    });

    tearDown(() => container.dispose());

    test(
      'valid title → formData.title updated, fieldErrors[title] is null',
      () {
        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        controller.updateField(field: 'title', value: 'Hello World Event');

        final state =
            container.read(createEventControllerProvider) as CreateEventEditing;
        expect(state.formData.title, 'Hello World Event');
        expect(state.fieldErrors['title'], isNull);
      },
    );

    test('invalid title (too short) → fieldErrors[title] is non-null', () {
      final controller = container.read(createEventControllerProvider.notifier);
      controller.updateField(field: 'title', value: 'hi');

      final state =
          container.read(createEventControllerProvider) as CreateEventEditing;
      expect(state.fieldErrors['title'], isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // canAdvance
  // ---------------------------------------------------------------------------
  group('canAdvance', () {
    late ProviderContainer container;
    late _MockLoadEventDraftUseCase load;
    late _MockSaveEventDraftUseCase save;

    setUp(() async {
      final result = _makeContainer();
      container = result.container;
      load = result.load;
      save = result.save;

      when(() => load(any())).thenAnswer((_) async => const Right(null));
      when(() => save(any())).thenAnswer((_) async => const Right(null));

      container.read(createEventControllerProvider);
      await Future<void>.value();
    });

    tearDown(() => container.dispose());

    test('step 0: valid title + category → canAdvance(0) is true', () {
      final controller = container.read(createEventControllerProvider.notifier);
      controller.updateField(field: 'title', value: 'Sunday Morning Hike');
      controller.updateField(field: 'category', value: EventCategory.hike);

      expect(controller.canAdvance(0), isTrue);
    });

    test('step 0: invalid title → canAdvance(0) is false', () {
      final controller = container.read(createEventControllerProvider.notifier);
      controller.updateField(field: 'title', value: 'hi'); // too short
      controller.updateField(field: 'category', value: EventCategory.hike);

      expect(controller.canAdvance(0), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // submit — success
  // ---------------------------------------------------------------------------
  group('submit — success', () {
    test(
      'CreateEventUseCase returns Right(Event) → SubmissionSuccess; ClearDraft called',
      () async {
        final (:container, :create, :load, :save, :clear) = _makeContainer();
        addTearDown(container.dispose);

        when(() => load(any())).thenAnswer((_) async => const Right(null));
        when(() => save(any())).thenAnswer((_) async => const Right(null));
        when(() => create(any())).thenAnswer((_) async => Right(_stubEvent()));
        when(() => clear(any())).thenAnswer((_) async => const Right(null));

        // Seed the controller with a fully-valid draft so submit() can build
        // CreateEventParams without triggering null asserts.
        container.read(createEventControllerProvider);
        await Future<void>.value();

        final controller = container.read(
          createEventControllerProvider.notifier,
        );

        // Load a valid draft via the controller's _loadDraftAndInit path is
        // async-only, so manually seed state by calling updateField for each
        // required field.
        final draft = _validDraft();
        controller.updateField(field: 'title', value: draft.title!);
        controller.updateField(field: 'category', value: draft.category!);
        controller.updateField(field: 'venueName', value: draft.venueName!);
        controller.updateField(field: 'latitude', value: draft.latitude!);
        controller.updateField(field: 'longitude', value: draft.longitude!);
        controller.updateField(field: 'startsAt', value: draft.startsAt!);
        controller.updateField(field: 'endsAt', value: draft.endsAt!);
        controller.updateField(field: 'capacity', value: draft.capacity!);
        controller.updateField(
          field: 'approvalMode',
          value: draft.approvalMode!,
        );
        controller.updateField(field: 'description', value: draft.description!);

        await controller.submit();

        final state = container.read(createEventControllerProvider);
        expect(state, isA<CreateEventSubmissionSuccess>());
        expect((state as CreateEventSubmissionSuccess).eventId, 'evt-1');

        // ClearDraft must have been called exactly once.
        verify(() => clear(any())).called(1);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // submit — failures
  // ---------------------------------------------------------------------------
  group('submit — failure mapping', () {
    late ProviderContainer container;
    late _MockCreateEventUseCase create;

    setUp(() async {
      final result = _makeContainer();
      container = result.container;
      create = result.create;
      final load = result.load;
      final save = result.save;

      when(() => load(any())).thenAnswer((_) async => const Right(null));
      when(() => save(any())).thenAnswer((_) async => const Right(null));

      container.read(createEventControllerProvider);
      await Future<void>.value();

      // Seed all required fields so submit() can proceed.
      final controller = container.read(createEventControllerProvider.notifier);
      final draft = _validDraft();
      controller.updateField(field: 'title', value: draft.title!);
      controller.updateField(field: 'category', value: draft.category!);
      controller.updateField(field: 'venueName', value: draft.venueName!);
      controller.updateField(field: 'latitude', value: draft.latitude!);
      controller.updateField(field: 'longitude', value: draft.longitude!);
      controller.updateField(field: 'startsAt', value: draft.startsAt!);
      controller.updateField(field: 'endsAt', value: draft.endsAt!);
      controller.updateField(field: 'capacity', value: draft.capacity!);
      controller.updateField(field: 'approvalMode', value: draft.approvalMode!);
      controller.updateField(field: 'description', value: draft.description!);
    });

    tearDown(() => container.dispose());

    test(
      'ValidationFailure → SubmissionError; returnToStep points to first bad field',
      () async {
        // ValidationFailure with fieldErrors on 'title' (step 0)
        const failure = ValidationFailure(
          'Validation failed',
          fieldErrors: {
            'title': ['Title is too short'],
          },
        );
        when(() => create(any())).thenAnswer((_) async => const Left(failure));

        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        await controller.submit();

        final state = container.read(createEventControllerProvider);
        expect(state, isA<CreateEventSubmissionError>());
        final error = state as CreateEventSubmissionError;
        // 'title' is in step 0; returnToStep must be 0.
        expect(error.returnToStep, 0);
        // The field error is mapped into fieldErrors.
        expect(error.fieldErrors['title'], isNotNull);
      },
    );

    test(
      'EmailNotVerifiedFailure → SubmissionError with _banner key',
      () async {
        const failure = EmailNotVerifiedFailure('Email not verified');
        when(() => create(any())).thenAnswer((_) async => const Left(failure));

        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        await controller.submit();

        final state = container.read(createEventControllerProvider);
        expect(state, isA<CreateEventSubmissionError>());
        expect(
          (state as CreateEventSubmissionError).fieldErrors['_banner'],
          isNotNull,
        );
      },
    );

    test('NetworkFailure → SubmissionError with _banner key', () async {
      const failure = NetworkFailure('Offline');
      when(() => create(any())).thenAnswer((_) async => const Left(failure));

      final controller = container.read(createEventControllerProvider.notifier);
      await controller.submit();

      final state = container.read(createEventControllerProvider);
      expect(state, isA<CreateEventSubmissionError>());
      expect(
        (state as CreateEventSubmissionError).fieldErrors['_banner'],
        isNotNull,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // discardDraft
  // ---------------------------------------------------------------------------
  group('discardDraft', () {
    test('calls ClearDraftUseCase and resets to fresh editing state', () async {
      final (:container, :create, :load, :save, :clear) = _makeContainer();
      addTearDown(container.dispose);

      when(() => load(any())).thenAnswer((_) async => const Right(null));
      when(() => save(any())).thenAnswer((_) async => const Right(null));
      when(() => clear(any())).thenAnswer((_) async => const Right(null));

      container.read(createEventControllerProvider);
      await Future<void>.value();

      final controller = container.read(createEventControllerProvider.notifier);
      await controller.discardDraft();

      verify(() => clear(any())).called(1);

      final state = container.read(createEventControllerProvider);
      expect(state, isA<CreateEventEditing>());
      final editing = state as CreateEventEditing;
      expect(editing.isResuming, isFalse);
      expect(editing.currentStep, 0);
      expect(editing.formData.title, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // acknowledgeResume
  // ---------------------------------------------------------------------------
  group('acknowledgeResume', () {
    test('clears isResuming flag while preserving draft', () async {
      final (:container, :create, :load, :save, :clear) = _makeContainer();
      addTearDown(container.dispose);

      final draft = const EventDraft(title: 'My Draft', currentStep: 2);
      when(() => load(any())).thenAnswer((_) async => Right(draft));
      when(() => save(any())).thenAnswer((_) async => const Right(null));

      container.read(createEventControllerProvider);
      // Two awaits: the first lets _loadDraftAndInit start; the second lets
      // the inner `await useCase(...)` complete (the mock's async function
      // schedules one extra microtask even when it returns immediately).
      await Future<void>.value();
      await Future<void>.value();

      // Confirm isResuming was set by the draft load.
      final before =
          container.read(createEventControllerProvider) as CreateEventEditing;
      expect(before.isResuming, isTrue);

      container
          .read(createEventControllerProvider.notifier)
          .acknowledgeResume();

      final after =
          container.read(createEventControllerProvider) as CreateEventEditing;
      expect(after.isResuming, isFalse);
      // Draft should still be intact.
      expect(after.formData.title, 'My Draft');
      expect(after.currentStep, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // canSubmit — cross-step full-form validation (Bug 2 regression lock)
  // ---------------------------------------------------------------------------
  group('canSubmit', () {
    late ProviderContainer container;

    setUp(() async {
      final result = _makeContainer();
      container = result.container;
      final load = result.load;
      final save = result.save;

      when(() => load(any())).thenAnswer((_) async => const Right(null));
      when(() => save(any())).thenAnswer((_) async => const Right(null));

      container.read(createEventControllerProvider);
      await Future<void>.value();
    });

    tearDown(() => container.dispose());

    test(
      'canSubmit returns false when only step-4 fields are valid but steps 1–3 have nulls',
      () {
        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        // Only seed description (step 4's field) — all prior steps remain null.
        controller.updateField(
          field: 'description',
          value: 'A lovely hike for solo travellers exploring Singapore.',
        );

        // canAdvance(4) is true — step 4's own field passes.
        expect(controller.canAdvance(4), isTrue);
        // canSubmit must be false — prior steps have null required fields.
        expect(controller.canSubmit(), isFalse);
      },
    );

    test('canSubmit returns true when all 10 fields are valid', () {
      final controller = container.read(createEventControllerProvider.notifier);
      final draft = _validDraft();
      controller.updateField(field: 'title', value: draft.title!);
      controller.updateField(field: 'category', value: draft.category!);
      controller.updateField(field: 'venueName', value: draft.venueName!);
      controller.updateField(field: 'latitude', value: draft.latitude!);
      controller.updateField(field: 'longitude', value: draft.longitude!);
      controller.updateField(field: 'startsAt', value: draft.startsAt!);
      controller.updateField(field: 'endsAt', value: draft.endsAt!);
      controller.updateField(field: 'capacity', value: draft.capacity!);
      controller.updateField(field: 'approvalMode', value: draft.approvalMode!);
      controller.updateField(field: 'description', value: draft.description!);

      expect(controller.canSubmit(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // submit — defense-in-depth null guard (Bug 2 regression lock)
  // ---------------------------------------------------------------------------
  group('submit — null guard', () {
    test(
      'submit() with missing required field maps to SubmissionError with _banner '
      'and returnToStep at the offending step, without calling the use case',
      () async {
        final (:container, :create, :load, :save, :clear) = _makeContainer();
        addTearDown(container.dispose);

        when(() => load(any())).thenAnswer((_) async => const Right(null));
        when(() => save(any())).thenAnswer((_) async => const Right(null));

        container.read(createEventControllerProvider);
        await Future<void>.value();

        final controller = container.read(
          createEventControllerProvider.notifier,
        );

        // Seed all required fields EXCEPT capacity (step 3).
        final draft = _validDraft();
        controller.updateField(field: 'title', value: draft.title!);
        controller.updateField(field: 'category', value: draft.category!);
        controller.updateField(field: 'venueName', value: draft.venueName!);
        controller.updateField(field: 'latitude', value: draft.latitude!);
        controller.updateField(field: 'longitude', value: draft.longitude!);
        controller.updateField(field: 'startsAt', value: draft.startsAt!);
        controller.updateField(field: 'endsAt', value: draft.endsAt!);
        // capacity intentionally omitted
        controller.updateField(
          field: 'approvalMode',
          value: draft.approvalMode!,
        );
        controller.updateField(field: 'description', value: draft.description!);

        await controller.submit();

        // The use case must never have been called.
        verifyNever(() => create(any()));

        final state = container.read(createEventControllerProvider);
        expect(state, isA<CreateEventSubmissionError>());
        final error = state as CreateEventSubmissionError;
        // capacity lives on step 3.
        expect(error.returnToStep, 3);
        expect(error.fieldErrors['_banner'], isNotNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // nextStep / previousStep keyboard dismissal (Bug 1 regression lock)
  // ---------------------------------------------------------------------------
  // These use testWidgets (not test) because focus changes in Flutter are
  // microtask-based (_markNeedsUpdate → scheduleMicrotask(applyFocusChanges)).
  // Only tester.pump() drains the microtask queue reliably, making the
  // primaryFocus assertion accurate. Using test() with attach(null) leaves
  // focus changes pending as unsettled microtasks.
  //
  // The widget tree is a minimal Directionality+Focus purely to anchor the
  // focus node in the live focus tree; providers are read directly from the
  // ProviderContainer, independent of ProviderScope.
  group('nextStep / previousStep keyboard dismissal', () {
    testWidgets('previousStep() unfocuses primary focus before mutating state', (
      tester,
    ) async {
      final result = _makeContainer();
      final container = result.container;
      when(() => result.load(any())).thenAnswer((_) async => const Right(null));
      when(() => result.save(any())).thenAnswer((_) async => const Right(null));

      // Pump a minimal widget tree to anchor the focus node in the live
      // focus tree. This is independent of the ProviderContainer.
      final focusNode = FocusNode();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Focus(focusNode: focusNode, child: const SizedBox()),
        ),
      );

      // Request focus and drain the microtask so primaryFocus is settled.
      focusNode.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      container.read(createEventControllerProvider);
      await Future<void>.value();

      final controller = container.read(createEventControllerProvider.notifier);
      // Navigate to step 1 first so previousStep() has somewhere to go.
      controller.goToStep(1);

      controller.previousStep();
      // Drain microtask so unfocus() settles.
      await tester.pump();

      // unfocus() with UnfocusDisposition.scope moves focus up to the
      // enclosing FocusScopeNode rather than setting primaryFocus to null.
      // A FocusScopeNode as primary focus is equivalent to keyboard dismissal —
      // no EditableText/TextInputClient is active. Both null and FocusScopeNode
      // are correct post-unfocus states in the test harness.
      expect(
        FocusManager.instance.primaryFocus,
        anyOf(isNull, isA<FocusScopeNode>()),
      );

      focusNode.dispose();
      container.dispose();
    });

    testWidgets('nextStep() unfocuses primary focus before mutating state', (
      tester,
    ) async {
      final result = _makeContainer();
      final container = result.container;
      when(() => result.load(any())).thenAnswer((_) async => const Right(null));
      when(() => result.save(any())).thenAnswer((_) async => const Right(null));

      final focusNode = FocusNode();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Focus(focusNode: focusNode, child: const SizedBox()),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      container.read(createEventControllerProvider);
      await Future<void>.value();

      final controller = container.read(createEventControllerProvider.notifier);
      controller.nextStep();
      await tester.pump();

      // See note in previousStep test: FocusScopeNode as primary focus is
      // equivalent to keyboard dismissal in the test harness.
      expect(
        FocusManager.instance.primaryFocus,
        anyOf(isNull, isA<FocusScopeNode>()),
      );

      focusNode.dispose();
      container.dispose();
    });
  });
}
