import 'dart:async';

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
import 'package:tribely/src/features/users/domain/entities/user_capabilities.dart';
import 'package:tribely/src/features/users/presentation/providers/capability_providers.dart';

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
// Fake capabilities notifiers
// ---------------------------------------------------------------------------

/// Synchronously resolves to [_caps] so [ref.read(myCapabilitiesProvider)]
/// immediately returns [AsyncData] in tests.
class _FakeMyCapabilitiesNotifier extends MyCapabilitiesNotifier {
  _FakeMyCapabilitiesNotifier(this._caps);
  final UserCapabilities _caps;

  @override
  Future<UserCapabilities> build() async => _caps;
}

/// Never resolves — keeps the provider in [AsyncLoading] for tests that need
/// capabilities to remain in the loading state.
class _LoadingMyCapabilitiesNotifier extends MyCapabilitiesNotifier {
  @override
  Future<UserCapabilities> build() => Completer<UserCapabilities>().future;
}

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
      category: 'restaurant',
    ),
    startsAt: DateTime(2030, 1, 1, 18),
    endsAt: DateTime(2030, 1, 1, 21),
    capacity: 10,
    category: EventCategory.drinks,
    costNotes: null,
    approvalMode: 'auto',
    status: 'published',
    createdAt: DateTime(2030, 1, 1),
    hostIsVerified: false,
  );
}

/// A fully-valid [EventDraft] that satisfies canAdvance(0) for step-0 tests
/// and can be submitted after all required fields are filled.
EventDraft _validDraft() {
  return EventDraft(
    // Step 0: cover photo storage key required.
    coverPhotoStorageKey: 'events/covers/test-key.jpg',
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

    test('step 0: coverPhotoStorageKey set → canAdvance(0) is true', () {
      final controller = container.read(createEventControllerProvider.notifier);
      controller.updateField(
        field: 'coverPhotoStorageKey',
        value: 'events/covers/test-key.jpg',
      );

      expect(controller.canAdvance(0), isTrue);
    });

    test('step 0: coverPhotoStorageKey null → canAdvance(0) is false', () {
      final controller = container.read(createEventControllerProvider.notifier);
      // No coverPhotoStorageKey set — fresh draft has null.

      expect(controller.canAdvance(0), isFalse);
    });

    test('step 1: valid title + category → canAdvance(1) is true', () {
      final controller = container.read(createEventControllerProvider.notifier);
      controller.updateField(field: 'title', value: 'Sunday Morning Hike');
      controller.updateField(field: 'category', value: EventCategory.hike);

      expect(controller.canAdvance(1), isTrue);
    });

    test('step 1: invalid title → canAdvance(1) is false', () {
      final controller = container.read(createEventControllerProvider.notifier);
      controller.updateField(field: 'title', value: 'hi'); // too short
      controller.updateField(field: 'category', value: EventCategory.hike);

      expect(controller.canAdvance(1), isFalse);
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
        controller.updateField(
          field: 'coverPhotoStorageKey',
          value: draft.coverPhotoStorageKey!,
        );
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
      controller.updateField(
        field: 'coverPhotoStorageKey',
        value: draft.coverPhotoStorageKey!,
      );
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
        // 'title' is in step 1 (after index shift); returnToStep must be 1.
        expect(error.returnToStep, 1);
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
      'canSubmit returns false when only step-5 fields are valid but steps 0–4 have nulls',
      () {
        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        // Only seed description (step 5's field) — all prior steps remain null.
        controller.updateField(
          field: 'description',
          value: 'A lovely hike for solo travellers exploring Singapore.',
        );

        // canAdvance(5) is true — step 5's own field passes.
        expect(controller.canAdvance(5), isTrue);
        // canSubmit must be false — prior steps have null required fields.
        expect(controller.canSubmit(), isFalse);
      },
    );

    test('canSubmit returns true when all 11 fields are valid', () {
      final controller = container.read(createEventControllerProvider.notifier);
      final draft = _validDraft();
      controller.updateField(
        field: 'coverPhotoStorageKey',
        value: draft.coverPhotoStorageKey!,
      );
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

        // Seed all required fields EXCEPT capacity (step 4 after index shift).
        final draft = _validDraft();
        controller.updateField(
          field: 'coverPhotoStorageKey',
          value: draft.coverPhotoStorageKey!,
        );
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
        // capacity lives on step 4 (after index shift).
        expect(error.returnToStep, 4);
        expect(error.fieldErrors['_banner'], isNotNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // A1: blockingFields derivation (Bug #5 regression lock)
  // ---------------------------------------------------------------------------
  group('blockingFields — derivation', () {
    late ProviderContainer container;

    setUp(() async {
      final result = _makeContainer();
      container = result.container;
      when(() => result.load(any())).thenAnswer((_) async => const Right(null));
      when(() => result.save(any())).thenAnswer((_) async => const Right(null));

      container.read(createEventControllerProvider);
      await Future<void>.value();
    });

    tearDown(() => container.dispose());

    test(
      'blockingFields contains step 3 with startsAt when startsAt is past the '
      '5-minute buffer and all other fields are valid',
      () {
        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        final baseDraft = _validDraft();

        // Seed all fields but use a startsAt that is too close to now (under
        // the 5-minute buffer). This simulates the time-decay race condition
        // where a previously-valid startsAt has decayed while the user lingers
        // on later steps.
        final decayedStartsAt = DateTime.now().add(const Duration(minutes: 3));

        controller.updateField(
          field: 'coverPhotoStorageKey',
          value: baseDraft.coverPhotoStorageKey!,
        );
        controller.updateField(field: 'title', value: baseDraft.title!);
        controller.updateField(field: 'category', value: baseDraft.category!);
        controller.updateField(field: 'venueName', value: baseDraft.venueName!);
        controller.updateField(field: 'latitude', value: baseDraft.latitude!);
        controller.updateField(field: 'longitude', value: baseDraft.longitude!);
        controller.updateField(field: 'startsAt', value: decayedStartsAt);
        controller.updateField(
          field: 'endsAt',
          value: decayedStartsAt.add(const Duration(hours: 2)),
        );
        controller.updateField(field: 'capacity', value: baseDraft.capacity!);
        controller.updateField(
          field: 'approvalMode',
          value: baseDraft.approvalMode!,
        );
        controller.updateField(
          field: 'description',
          value: baseDraft.description!,
        );

        final state =
            container.read(createEventControllerProvider) as CreateEventEditing;

        // Step 3 owns startsAt (after index shift) — must appear in blockingFields.
        expect(state.blockingFields.containsKey(3), isTrue);
        expect(state.blockingFields[3], contains('startsAt'));
        // canSubmit must be false — startsAt is invalid.
        expect(controller.canSubmit(), isFalse);
      },
    );

    test(
      'blockingFields is empty when all fields are valid with far-future startsAt',
      () {
        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        final draft = _validDraft(); // uses DateTime(2030, ...) — always valid

        controller.updateField(
          field: 'coverPhotoStorageKey',
          value: draft.coverPhotoStorageKey!,
        );
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

        final state =
            container.read(createEventControllerProvider) as CreateEventEditing;

        expect(state.blockingFields, isEmpty);
        expect(controller.canSubmit(), isTrue);
      },
    );

    test('goToStep triggers state emission that re-derives blockingFields — '
        'time-decayed startsAt surfaces after step transition', () async {
      final controller = container.read(createEventControllerProvider.notifier);
      final baseDraft = _validDraft();

      // Use a startsAt that is already past the 5-minute buffer so the
      // validator fails on first evaluation (simulates decay).
      final decayedStartsAt = DateTime.now().add(const Duration(minutes: 3));

      controller.updateField(
        field: 'coverPhotoStorageKey',
        value: baseDraft.coverPhotoStorageKey!,
      );
      controller.updateField(field: 'title', value: baseDraft.title!);
      controller.updateField(field: 'category', value: baseDraft.category!);
      controller.updateField(field: 'venueName', value: baseDraft.venueName!);
      controller.updateField(field: 'latitude', value: baseDraft.latitude!);
      controller.updateField(field: 'longitude', value: baseDraft.longitude!);
      controller.updateField(field: 'startsAt', value: decayedStartsAt);
      controller.updateField(
        field: 'endsAt',
        value: decayedStartsAt.add(const Duration(hours: 2)),
      );
      controller.updateField(field: 'capacity', value: baseDraft.capacity!);
      controller.updateField(
        field: 'approvalMode',
        value: baseDraft.approvalMode!,
      );
      controller.updateField(
        field: 'description',
        value: baseDraft.description!,
      );

      // Navigate to step 5 (Step 6 / Describe+Review) — goToStep must re-derive blockingFields.
      controller.goToStep(5);

      final state =
          container.read(createEventControllerProvider) as CreateEventEditing;

      // Step 3 owns startsAt (after index shift) — must appear in blockingFields.
      expect(state.blockingFields.containsKey(3), isTrue);
      expect(state.blockingFields[3], contains('startsAt'));
      // canSubmit must be false.
      expect(controller.canSubmit(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // A4: default approvalMode (Bug #5 regression lock)
  // ---------------------------------------------------------------------------
  group('EventDraft default approvalMode', () {
    test('fresh EventDraft() has approvalMode == manual', () {
      const draft = EventDraft();
      expect(draft.approvalMode, 'manual');
    });
  });

  // ---------------------------------------------------------------------------
  // nextStep / previousStep keyboard dismissal — REMOVED (arch review Q2)
  // ---------------------------------------------------------------------------
  // Focus dismissal was previously a controller concern but moved to the page
  // in commit 883e0b9 (architecture review Q2, 2026-05-15) — Notifier controllers
  // are pure-Dart with no Flutter widget-tree imports. The contract is now
  // exercised by the page widget's `_dismissFocusAndCall` helper around
  // `controller.nextStep()` / `controller.previousStep()`. Page-level widget
  // test coverage is a follow-up.
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Brief 9: selectVenueCategory + onVenueNameChanged — private-venue warnings
  // ---------------------------------------------------------------------------
  //
  // The controller reads [myCapabilitiesProvider] synchronously (AsyncValue).
  // Tests override [myCapabilitiesProvider] directly via ProviderContainer
  // overrides to control the loading/data/error states without a network call.
  //
  // Warning invariants:
  //   A. Public category + clean name → PrivateVenueWarningNone
  //   B. Private category (e.g. 'apartment') + no caps loaded → FirstTimeHost
  //   C. Private category + caps(canPostPrivateVenue: true) → EstablishedHost
  //   D. Keyword match in venue name + no category → FirstTimeHost
  // ---------------------------------------------------------------------------

  /// Build a container that also overrides [myCapabilitiesProvider] with a
  /// resolved [UserCapabilities] value.
  ({
    ProviderContainer container,
    _MockCreateEventUseCase create,
    _MockLoadEventDraftUseCase load,
    _MockSaveEventDraftUseCase save,
    _MockClearEventDraftUseCase clear,
  })
  makeContainerWithCaps({required UserCapabilities caps}) {
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
        myCapabilitiesProvider.overrideWith(
          () => _FakeMyCapabilitiesNotifier(caps),
        ),
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

  group('selectVenueCategory — private-venue warning (Brief 9)', () {
    // A. Public category + clean name → no warning
    test(
      'A: selecting a public category with a clean venue name → PrivateVenueWarningNone',
      () async {
        final result = makeContainerWithCaps(
          caps: const UserCapabilities.restricted(),
        );
        final container = result.container;
        addTearDown(container.dispose);

        when(
          () => result.load(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => result.save(any()),
        ).thenAnswer((_) async => const Right(null));

        container.read(createEventControllerProvider);
        await Future<void>.value();

        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        // Set a clean venue name first.
        controller.updateField(field: 'venueName', value: 'Gardens by the Bay');
        // Select a public category.
        controller.selectVenueCategory('park');

        final state =
            container.read(createEventControllerProvider) as CreateEventEditing;
        expect(state.selectedVenueCategory, 'park');
        expect(state.privateVenueWarning, isA<PrivateVenueWarningNone>());
      },
    );

    // B. Private category + no caps loaded → FirstTimeHost warning
    test(
      'B: selecting a private category ("apartment") with caps not yet loaded → PrivateVenueWarningFirstTimeHost',
      () async {
        // Override myCapabilitiesProvider to stay in loading state indefinitely
        // by using a completer that never completes within the test.
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
            // Caps stay in loading state — never resolves.
            myCapabilitiesProvider.overrideWith(
              _LoadingMyCapabilitiesNotifier.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        when(() => load(any())).thenAnswer((_) async => const Right(null));
        when(() => save(any())).thenAnswer((_) async => const Right(null));

        container.read(createEventControllerProvider);
        await Future<void>.value();

        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        controller.selectVenueCategory('apartment');

        final state =
            container.read(createEventControllerProvider) as CreateEventEditing;
        expect(
          state.privateVenueWarning,
          isA<PrivateVenueWarningFirstTimeHost>(),
        );
      },
    );

    // C. Private category + caps(canPostPrivateVenue: true) → EstablishedHost
    test(
      'C: selecting a private category with canPostPrivateVenue=true → PrivateVenueWarningEstablishedHost',
      () async {
        final result = makeContainerWithCaps(
          caps: const UserCapabilities(
            canPostPrivateVenue: true,
            safetyReminderSeen: false,
          ),
        );
        final container = result.container;
        addTearDown(container.dispose);

        when(
          () => result.load(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => result.save(any()),
        ).thenAnswer((_) async => const Right(null));

        // Let the caps provider settle before initialising the controller so
        // that ref.read(myCapabilitiesProvider) returns AsyncData on first call.
        await container.read(myCapabilitiesProvider.future);

        container.read(createEventControllerProvider);
        await Future<void>.value();

        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        controller.selectVenueCategory('apartment');

        final state =
            container.read(createEventControllerProvider) as CreateEventEditing;
        expect(
          state.privateVenueWarning,
          isA<PrivateVenueWarningEstablishedHost>(),
        );
      },
    );

    // D. Keyword in venue name with no category → FirstTimeHost warning (Brief 9)
    test(
      'D: typing "my apartment" in venue name with no category selected → PrivateVenueWarningFirstTimeHost',
      () async {
        final result = makeContainerWithCaps(
          caps: const UserCapabilities.restricted(),
        );
        final container = result.container;
        addTearDown(container.dispose);

        when(
          () => result.load(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => result.save(any()),
        ).thenAnswer((_) async => const Right(null));

        // Let the caps provider settle (restricted = canPostPrivateVenue: false)
        // so ref.read(myCapabilitiesProvider) returns AsyncData on first call.
        await container.read(myCapabilitiesProvider.future);

        container.read(createEventControllerProvider);
        await Future<void>.value();

        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        // No category selected — null.
        controller.onVenueNameChanged('my apartment');

        final state =
            container.read(createEventControllerProvider) as CreateEventEditing;
        expect(
          state.privateVenueWarning,
          isA<PrivateVenueWarningFirstTimeHost>(),
        );
      },
    );

    // E. Selecting the same chip twice is a no-op (Brief 9)
    test(
      'E: selectVenueCategory called twice with the same value is a no-op on state',
      () async {
        final result = makeContainerWithCaps(
          caps: const UserCapabilities.restricted(),
        );
        final container = result.container;
        addTearDown(container.dispose);

        when(
          () => result.load(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => result.save(any()),
        ).thenAnswer((_) async => const Right(null));

        container.read(createEventControllerProvider);
        await Future<void>.value();

        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        controller.selectVenueCategory('cafe');

        final stateAfterFirst =
            container.read(createEventControllerProvider) as CreateEventEditing;

        // Second tap on the same chip.
        controller.selectVenueCategory('cafe');

        final stateAfterSecond =
            container.read(createEventControllerProvider) as CreateEventEditing;

        // State should remain identical (the controller guards against no-op mutations).
        expect(stateAfterSecond, equals(stateAfterFirst));
      },
    );

    // F. selectedVenueCategory mirrors EventDraft.venueCategory (Brief 9)
    test(
      'F: selectVenueCategory updates both selectedVenueCategory and draft.venueCategory',
      () async {
        final result = makeContainerWithCaps(
          caps: const UserCapabilities.restricted(),
        );
        final container = result.container;
        addTearDown(container.dispose);

        when(
          () => result.load(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => result.save(any()),
        ).thenAnswer((_) async => const Right(null));

        container.read(createEventControllerProvider);
        await Future<void>.value();

        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        controller.selectVenueCategory('museum');

        final state =
            container.read(createEventControllerProvider) as CreateEventEditing;
        expect(state.selectedVenueCategory, 'museum');
        expect(state.formData.venueCategory, 'museum');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Brief 11: FirstEventMustBePublicFailure — recovery flow
  //
  // Tests the two branches of [onPublishRejectionAcknowledged]:
  //   1. pickPublicPlace: clears venue fields, navigates to Step 2, all other
  //      fields preserved, publishRejection cleared.
  //   2. cancel: stays on Step 5, publishRejection cleared, venue fields intact.
  //
  // Uses makeContainerWithCaps with restricted caps (canPostPrivateVenue=false)
  // so the private-venue warning machinery also exercises the right path.
  // ---------------------------------------------------------------------------

  /// A fully-valid draft where venueCategory is a private category. This
  /// triggers [FirstEventMustBePublicFailure] on the server side.
  EventDraft validDraftWithPrivateVenue() {
    return EventDraft(
      coverPhotoStorageKey: 'events/covers/test-key.jpg',
      title: 'Sunday Morning Hike',
      category: EventCategory.hike,
      venueName: 'My Apartment Block',
      venueCategory: 'apartment',
      latitude: 1.28,
      longitude: 103.85,
      startsAt: DateTime(2030, 6, 1, 8),
      endsAt: DateTime(2030, 6, 1, 11),
      capacity: 10,
      approvalMode: 'auto',
      description: 'A lovely hike for solo travellers exploring Singapore.',
      currentStep: 5,
    );
  }

  /// Seeds the controller with all fields from [draft] via [updateField] and
  /// [selectVenueCategory], then navigates to step 5 (Step 6 / Describe+Review).
  Future<void> seedControllerWithDraft(
    ProviderContainer container,
    EventDraft draft,
  ) async {
    final controller = container.read(createEventControllerProvider.notifier);
    if (draft.coverPhotoStorageKey != null) {
      controller.updateField(
        field: 'coverPhotoStorageKey',
        value: draft.coverPhotoStorageKey!,
      );
    }
    controller.updateField(field: 'title', value: draft.title!);
    controller.updateField(field: 'category', value: draft.category!);
    controller.updateField(field: 'venueName', value: draft.venueName!);
    if (draft.venueCategory != null) {
      controller.selectVenueCategory(draft.venueCategory!);
    }
    controller.updateField(field: 'latitude', value: draft.latitude!);
    controller.updateField(field: 'longitude', value: draft.longitude!);
    controller.updateField(field: 'startsAt', value: draft.startsAt!);
    controller.updateField(field: 'endsAt', value: draft.endsAt!);
    controller.updateField(field: 'capacity', value: draft.capacity!);
    controller.updateField(field: 'approvalMode', value: draft.approvalMode!);
    controller.updateField(field: 'description', value: draft.description!);
    controller.goToStep(5);
  }

  group('submit — FirstEventMustBePublicFailure (Brief 11)', () {
    test(
      'server returns FirstEventMustBePublicFailure → '
      'state is CreateEventEditing on Step 5 with publishRejection set',
      () async {
        final result = makeContainerWithCaps(
          caps: const UserCapabilities.restricted(),
        );
        final container = result.container;
        addTearDown(container.dispose);

        when(
          () => result.load(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => result.save(any()),
        ).thenAnswer((_) async => const Right(null));
        when(() => result.create(any())).thenAnswer(
          (_) async => const Left(
            FirstEventMustBePublicFailure(reason: 'category_not_public'),
          ),
        );

        container.read(createEventControllerProvider);
        await Future<void>.value();

        final draft = validDraftWithPrivateVenue();
        await seedControllerWithDraft(container, draft);

        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        await controller.submit();

        final state = container.read(createEventControllerProvider);
        expect(state, isA<CreateEventEditing>());
        final editing = state as CreateEventEditing;
        // publishRejection must be set.
        expect(
          editing.publishRejection,
          isA<PublishRejectionFirstEventMustBePublic>(),
        );
        // Must remain on Step 6 (index 5 after cover-photo shift).
        expect(editing.currentStep, 5);
      },
    );
  });

  group('onPublishRejectionAcknowledged — pickPublicPlace (Brief 11)', () {
    test('pickPublicPlace: clears venue fields, navigates to Step 2, '
        'preserves all other fields, clears publishRejection', () async {
      final result = makeContainerWithCaps(
        caps: const UserCapabilities.restricted(),
      );
      final container = result.container;
      addTearDown(container.dispose);

      when(() => result.load(any())).thenAnswer((_) async => const Right(null));
      when(() => result.save(any())).thenAnswer((_) async => const Right(null));
      when(() => result.create(any())).thenAnswer(
        (_) async => const Left(
          FirstEventMustBePublicFailure(reason: 'category_not_public'),
        ),
      );

      container.read(createEventControllerProvider);
      await Future<void>.value();

      final draft = validDraftWithPrivateVenue();
      await seedControllerWithDraft(container, draft);

      final controller = container.read(createEventControllerProvider.notifier);
      await controller.submit();

      // Confirm rejection was set.
      final rejectedState =
          container.read(createEventControllerProvider) as CreateEventEditing;
      expect(
        rejectedState.publishRejection,
        isA<PublishRejectionFirstEventMustBePublic>(),
      );

      // Acknowledge with pickPublicPlace.
      controller.onPublishRejectionAcknowledged(
        FirstEventMustBePublicModalResult.pickPublicPlace,
      );

      final afterState =
          container.read(createEventControllerProvider) as CreateEventEditing;

      // publishRejection must be cleared.
      expect(afterState.publishRejection, isNull);

      // Step must be 3 (venue step, index 2 after cover-photo shift).
      expect(afterState.currentStep, 2);

      // Venue fields must be cleared.
      expect(afterState.formData.venueName, isNull);
      expect(afterState.formData.venueCategory, isNull);
      expect(afterState.selectedVenueCategory, isNull);

      // All other fields must be preserved.
      expect(afterState.formData.title, draft.title);
      expect(afterState.formData.category, draft.category);
      expect(afterState.formData.latitude, draft.latitude);
      expect(afterState.formData.longitude, draft.longitude);
      expect(afterState.formData.startsAt, draft.startsAt);
      expect(afterState.formData.endsAt, draft.endsAt);
      expect(afterState.formData.capacity, draft.capacity);
      expect(afterState.formData.approvalMode, draft.approvalMode);
      expect(afterState.formData.description, draft.description);
    });
  });

  // ---------------------------------------------------------------------------
  // TRI-51: costNotes field — optional, never gates canSubmit / blockingFields
  // ---------------------------------------------------------------------------
  group('costNotes field — optional (TRI-51)', () {
    late ProviderContainer container;
    late _MockSaveEventDraftUseCase save;

    setUp(() async {
      final result = _makeContainer();
      container = result.container;
      save = result.save;
      when(() => result.load(any())).thenAnswer((_) async => const Right(null));
      when(() => save(any())).thenAnswer((_) async => const Right(null));

      container.read(createEventControllerProvider);
      await Future<void>.value();
    });

    tearDown(() => container.dispose());

    test(
      'updateField costNotes writes draft.costNotes and does NOT add to blockingFields',
      () {
        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        controller.updateField(field: 'costNotes', value: 'Pay your own way');

        final state =
            container.read(createEventControllerProvider) as CreateEventEditing;
        expect(state.formData.costNotes, 'Pay your own way');
        // costNotes must never appear in blockingFields across any step.
        for (final stepFields in state.blockingFields.values) {
          expect(stepFields, isNot(contains('costNotes')));
        }
      },
    );

    test(
      'canSubmit is true with all required fields valid and costNotes null',
      () {
        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        final draft = _validDraft();
        controller.updateField(
          field: 'coverPhotoStorageKey',
          value: draft.coverPhotoStorageKey!,
        );
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
        // costNotes intentionally NOT set — must still be submittable.

        expect(controller.canSubmit(), isTrue);
      },
    );
  });

  group('onPublishRejectionAcknowledged — cancel (Brief 11)', () {
    test(
      'cancel: stays on Step 5, clears publishRejection, venue fields intact',
      () async {
        final result = makeContainerWithCaps(
          caps: const UserCapabilities.restricted(),
        );
        final container = result.container;
        addTearDown(container.dispose);

        when(
          () => result.load(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => result.save(any()),
        ).thenAnswer((_) async => const Right(null));
        when(() => result.create(any())).thenAnswer(
          (_) async => const Left(
            FirstEventMustBePublicFailure(reason: 'category_not_public'),
          ),
        );

        container.read(createEventControllerProvider);
        await Future<void>.value();

        final draft = validDraftWithPrivateVenue();
        await seedControllerWithDraft(container, draft);

        final controller = container.read(
          createEventControllerProvider.notifier,
        );
        await controller.submit();

        // Acknowledge with cancel.
        controller.onPublishRejectionAcknowledged(
          FirstEventMustBePublicModalResult.cancel,
        );

        final afterState =
            container.read(createEventControllerProvider) as CreateEventEditing;

        // publishRejection must be cleared.
        expect(afterState.publishRejection, isNull);

        // Must still be on Step 6 (index 5 after cover-photo shift).
        expect(afterState.currentStep, 5);

        // Venue fields must be intact — host can retry or edit manually.
        expect(afterState.formData.venueName, draft.venueName);
        expect(afterState.formData.venueCategory, draft.venueCategory);
      },
    );
  });
}
