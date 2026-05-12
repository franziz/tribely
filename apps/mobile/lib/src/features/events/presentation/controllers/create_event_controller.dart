import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/event_category.dart';
import '../../domain/entities/event_draft.dart';
import '../../domain/repositories/event_repository.dart';
import '../../domain/validators/event_validators.dart';
import '../providers/events_providers.dart';
import '../state/create_event_state.dart';

/// Owns the multi-step create-event state machine.
///
/// Responsibilities:
///   - Draft load on init (isResuming flag for the resume dialog)
///   - Per-field validation + inline error map (fieldErrors)
///   - Debounced autosave (500ms) on every field change
///   - Step navigation (goToStep / nextStep / previousStep)
///   - canAdvance gate — validates all fields for the requested step
///   - Submit orchestration → CreateEventSubmitting → Success | Error
///   - discardDraft / acknowledgeResume / dismissResumePrompt
///
/// Navigation is NOT performed here. On success the page observes
/// [CreateEventSubmissionSuccess] and calls context.go(...).
class CreateEventController extends Notifier<CreateEventState> {
  Timer? _autosaveTimer;

  // ---------------------------------------------------------------------------
  // Step → field mapping (canonical source of truth for both canAdvance and
  // submit failure routing).
  // ---------------------------------------------------------------------------

  static const Map<int, List<String>> _stepFields = {
    0: ['title', 'category'],
    1: ['venueName', 'latitude', 'longitude'],
    2: ['startsAt', 'endsAt'],
    3: ['capacity', 'approvalMode'],
    4: ['description'],
  };

  // ---------------------------------------------------------------------------
  // build — synchronous return, async init kicked off as a side-effect.
  // Follows the same pattern as SessionController to satisfy Riverpod 3's
  // "no provider mutation during build" rule.
  // ---------------------------------------------------------------------------

  @override
  CreateEventState build() {
    ref.onDispose(() {
      _autosaveTimer?.cancel();
    });

    Future(_loadDraftAndInit);

    return const CreateEventEditing(
      formData: EventDraft(),
      currentStep: 0,
      fieldErrors: {},
      isResuming: false,
    );
  }

  Future<void> _loadDraftAndInit() async {
    if (!ref.mounted) return;
    final useCase = ref.read(loadEventDraftUseCaseProvider);
    final result = await useCase(const NoParams());

    if (!ref.mounted) return;

    result.fold(
      (failure) {
        // Draft load failure — log and start fresh. Don't block the create flow.
        // ignore: avoid_print
        print('[CreateEventController] Failed to load draft: ${failure.message}');
        // state is already the fresh editing state set by build(); nothing to do.
      },
      (draft) {
        if (draft != null) {
          state = CreateEventEditing(
            formData: draft,
            currentStep: draft.currentStep,
            fieldErrors: const {},
            isResuming: true,
          );
        }
        // draft == null: state is already the fresh editing state — no change.
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Field update + debounced autosave
  // ---------------------------------------------------------------------------

  /// Update a single field on the form data, run its validator, and schedule
  /// a debounced autosave (500ms, reset on each call).
  ///
  /// [field] must be one of the documented field names (title, category,
  /// venueName, latitude, longitude, startsAt, endsAt, capacity,
  /// approvalMode, description).
  ///
  /// [value] must be the Dart type matching the field:
  ///   - title, venueName, approvalMode, description → String?
  ///   - category → EventCategory?
  ///   - latitude, longitude → double?
  ///   - startsAt, endsAt → DateTime?
  ///   - capacity → int?
  void updateField({required String field, required Object? value}) {
    final current = state;
    if (current is! CreateEventEditing) return;

    final updatedDraft = _applyFieldToDraft(current.formData, field, value);
    final error = _validateField(field, updatedDraft);

    final updatedErrors = Map<String, String?>.from(current.fieldErrors)
      ..[field] = error;

    state = current.copyWith(
      formData: updatedDraft,
      fieldErrors: updatedErrors,
    );

    _scheduleAutosave(updatedDraft);
  }

  EventDraft _applyFieldToDraft(EventDraft draft, String field, Object? value) {
    return switch (field) {
      'title' => draft.copyWith(title: value as String?),
      'category' => draft.copyWith(category: value as EventCategory?),
      'venueName' => draft.copyWith(venueName: value as String?),
      'latitude' => draft.copyWith(latitude: value as double?),
      'longitude' => draft.copyWith(longitude: value as double?),
      'startsAt' => draft.copyWith(startsAt: value as DateTime?),
      'endsAt' => draft.copyWith(endsAt: value as DateTime?),
      'capacity' => draft.copyWith(capacity: value as int?),
      'approvalMode' => draft.copyWith(approvalMode: value as String?),
      'description' => draft.copyWith(description: value as String?),
      _ => draft,
    };
  }

  /// Runs the matching pure validator for [field]. Returns null on valid, an
  /// error message on invalid.
  String? _validateField(String field, EventDraft draft) {
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

  void _scheduleAutosave(EventDraft draft) {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!ref.mounted) return;
      final saveUseCase = ref.read(saveEventDraftUseCaseProvider);
      // Fire-and-forget: autosave failures are non-fatal. The user still
      // has the in-memory state and can retry on the next field edit.
      await saveUseCase(draft);
    });
  }

  // ---------------------------------------------------------------------------
  // Step navigation
  // ---------------------------------------------------------------------------

  /// Validate all fields belonging to [step]. Returns true iff every field
  /// passes its validator. The page binds the Next button's enabled state to
  /// this method.
  bool canAdvance(int step) {
    final current = state;
    if (current is! CreateEventEditing) return false;
    final draft = current.formData;
    final fields = _stepFields[step] ?? [];
    return fields.every((field) => _validateField(field, draft) == null);
  }

  void goToStep(int step) {
    final current = state;
    if (current is! CreateEventEditing) return;
    assert(step >= 0 && step <= 4, 'step must be in range 0–4');
    state = current.copyWith(
      formData: current.formData.copyWith(currentStep: step),
      currentStep: step,
    );
  }

  void nextStep() {
    final current = state;
    if (current is! CreateEventEditing) return;
    if (current.currentStep < 4) {
      goToStep(current.currentStep + 1);
    }
  }

  void previousStep() {
    final current = state;
    if (current is! CreateEventEditing) return;
    if (current.currentStep > 0) {
      goToStep(current.currentStep - 1);
    }
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> submit() async {
    final current = state;
    if (current is! CreateEventEditing) return;
    final draft = current.formData;

    state = CreateEventSubmitting(draft);

    // Build CreateEventParams — assert non-null fields; a null here is a
    // validator-gating bug and must surface loudly in development.
    assert(draft.title != null, 'title must not be null at submit time');
    assert(draft.category != null, 'category must not be null at submit time');
    assert(draft.venueName != null, 'venueName must not be null at submit time');
    assert(draft.latitude != null, 'latitude must not be null at submit time');
    assert(draft.longitude != null, 'longitude must not be null at submit time');
    assert(draft.startsAt != null, 'startsAt must not be null at submit time');
    assert(draft.endsAt != null, 'endsAt must not be null at submit time');
    assert(draft.capacity != null, 'capacity must not be null at submit time');
    assert(draft.approvalMode != null, 'approvalMode must not be null at submit time');
    assert(draft.description != null, 'description must not be null at submit time');

    final params = CreateEventParams(
      title: draft.title!,
      category: draft.category!,
      venueName: draft.venueName!,
      latitude: draft.latitude!,
      longitude: draft.longitude!,
      startsAt: draft.startsAt!,
      endsAt: draft.endsAt!,
      capacity: draft.capacity!,
      approvalMode: draft.approvalMode!,
      description: draft.description!,
    );

    if (!ref.mounted) return;
    final createUseCase = ref.read(createEventUseCaseProvider);
    final result = await createUseCase(params);

    if (!ref.mounted) return;

    await result.fold(
      (failure) async => _handleSubmitFailure(failure, draft, current.currentStep),
      (event) async {
        final clearUseCase = ref.read(clearEventDraftUseCaseProvider);
        await clearUseCase(const NoParams());
        if (!ref.mounted) return;
        state = CreateEventSubmissionSuccess(event.id);
      },
    );
  }

  void _handleSubmitFailure(
    Failure failure,
    EventDraft draft,
    int currentStep,
  ) {
    final (returnToStep, fieldErrors) = switch (failure) {
      ValidationFailure(:final fieldErrors) when fieldErrors != null => (
          _stepForFirstFieldError(fieldErrors, currentStep),
          _flattenFieldErrors(fieldErrors),
        ),
      ValidationFailure() => (
          currentStep,
          <String, String?>{'_banner': failure.message},
        ),
      EmailNotVerifiedFailure() => (
          currentStep,
          <String, String?>{
            '_banner': 'Please verify your email to create an event.',
          },
        ),
      NetworkFailure() => (
          currentStep,
          <String, String?>{
            '_banner': "You're offline. Please try again.",
          },
        ),
      _ => (
          currentStep,
          <String, String?>{'_banner': failure.message},
        ),
    };

    state = CreateEventSubmissionError(
      formData: draft,
      failure: failure,
      returnToStep: returnToStep,
      fieldErrors: fieldErrors,
    );
  }

  /// Given a field-to-list-of-error-messages map from [ValidationFailure], find
  /// the step index that owns the first field with an error.
  int _stepForFirstFieldError(
    Map<String, List<String>> fieldErrors,
    int fallbackStep,
  ) {
    for (final entry in _stepFields.entries) {
      for (final field in entry.value) {
        if (fieldErrors.containsKey(field)) {
          return entry.key;
        }
      }
    }
    return fallbackStep;
  }

  /// Flatten [ValidationFailure.fieldErrors] (field to list-of-messages) into
  /// the controller's (field to String?) shape, keeping only the first message per field.
  Map<String, String?> _flattenFieldErrors(Map<String, List<String>> raw) {
    return {
      for (final entry in raw.entries)
        entry.key: entry.value.isNotEmpty ? entry.value.first : null,
    };
  }

  // ---------------------------------------------------------------------------
  // Draft lifecycle
  // ---------------------------------------------------------------------------

  /// Clear the local draft and reset to a fresh editing state. Called when
  /// the user explicitly discards their draft from the resume dialog.
  Future<void> discardDraft() async {
    _autosaveTimer?.cancel();

    final clearUseCase = ref.read(clearEventDraftUseCaseProvider);
    await clearUseCase(const NoParams());

    if (!ref.mounted) return;
    state = const CreateEventEditing(
      formData: EventDraft(),
      currentStep: 0,
      fieldErrors: {},
      isResuming: false,
    );
  }

  /// Called when the user taps "Resume" in the resume dialog. Clears the
  /// [isResuming] flag so the dialog does not appear again.
  void acknowledgeResume() {
    final current = state;
    if (current is! CreateEventEditing) return;
    state = current.copyWith(isResuming: false);
  }

  /// Alias for [acknowledgeResume] — the dismiss action also clears the flag
  /// without discarding the draft. The page continues with the loaded draft.
  void dismissResumePrompt() => acknowledgeResume();
}
