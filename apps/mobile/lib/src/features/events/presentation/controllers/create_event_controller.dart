import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../users/presentation/providers/capability_providers.dart';
import '../../domain/entities/event_category.dart';
import '../../domain/entities/event_draft.dart';
import '../../domain/repositories/event_repository.dart';
import '../../domain/services/private_venue_policy.dart';
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

    Future.microtask(_loadDraftAndInit);

    const freshDraft = EventDraft();
    final (:blockingFields, :blockingFieldErrors) = _deriveBlocking(freshDraft);
    return CreateEventEditing(
      formData: freshDraft,
      currentStep: 0,
      fieldErrors: const {},
      isResuming: false,
      blockingFields: blockingFields,
      blockingFieldErrors: blockingFieldErrors,
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
        debugPrint(
          '[CreateEventController] Failed to load draft: ${failure.message}',
        );
        // state is already the fresh editing state set by build(); nothing to do.
      },
      (draft) {
        if (draft != null) {
          final (:blockingFields, :blockingFieldErrors) = _deriveBlocking(
            draft,
          );
          state = CreateEventEditing(
            formData: draft,
            currentStep: draft.currentStep,
            fieldErrors: const {},
            isResuming: true,
            blockingFields: blockingFields,
            blockingFieldErrors: blockingFieldErrors,
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

    final (:blockingFields, :blockingFieldErrors) = _deriveBlocking(
      updatedDraft,
    );
    state = current.copyWith(
      formData: updatedDraft,
      fieldErrors: updatedErrors,
      blockingFields: blockingFields,
      blockingFieldErrors: blockingFieldErrors,
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

  /// Derives both blocking-field maps for [draft].
  ///
  /// Returns:
  ///   - [blockingFields]: step index → list of field names that fail.
  ///   - [blockingFieldErrors]: step index → list of (fieldName, errorMessage).
  ///
  /// An empty [blockingFields] map means the form is publishable.
  ///
  /// Note: time-dependent validators (currently only [validateStartsAt]) call
  /// [DateTime.now()] on every invocation — so these maps re-evaluate against
  /// wall-clock time whenever called. Callers that need a fresh time surface
  /// (step transitions, page resume) should trigger a state emission via
  /// [goToStep] or [refreshBlockingFields].
  ///
  /// TODO(TRI-55): inject a Clock port here so tests can stub wall-clock time
  /// without the ad-hoc DateTime Function() parameter workaround.
  ({
    Map<int, List<String>> blockingFields,
    Map<int, List<(String, String)>> blockingFieldErrors,
  })
  _deriveBlocking(EventDraft draft) {
    final fields = <int, List<String>>{};
    final errors = <int, List<(String, String)>>{};
    for (final entry in _stepFields.entries) {
      final failingFields = <String>[];
      final failingErrors = <(String, String)>[];
      for (final field in entry.value) {
        final error = _validateField(field, draft);
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

  /// Returns true iff the named field's value on [draft] is null. Used by the
  /// defense-in-depth guard in [submit] to detect bypassed gating.
  bool _draftFieldIsNull(String field, EventDraft draft) {
    return switch (field) {
      'title' => draft.title == null,
      'category' => draft.category == null,
      'venueName' => draft.venueName == null,
      'latitude' => draft.latitude == null,
      'longitude' => draft.longitude == null,
      'startsAt' => draft.startsAt == null,
      'endsAt' => draft.endsAt == null,
      'capacity' => draft.capacity == null,
      'approvalMode' => draft.approvalMode == null,
      'description' => draft.description == null,
      _ => false,
    };
  }

  // ---------------------------------------------------------------------------
  // Venue category selection + private-venue warning (Brief 9)
  // ---------------------------------------------------------------------------

  /// Select a venue category chip on Step 2.
  ///
  /// Updates [CreateEventEditing.selectedVenueCategory] + [EventDraft.venueCategory]
  /// in a single state emission, then recomputes the private-venue warning.
  /// Tapping the already-selected chip is a no-op (single-select, no deselect).
  void selectVenueCategory(String value) {
    final current = state;
    if (current is! CreateEventEditing) return;
    if (current.selectedVenueCategory == value) return;

    final updatedDraft = current.formData.copyWith(venueCategory: value);
    final warning = _computeWarning(value, updatedDraft.venueName ?? '');
    final (:blockingFields, :blockingFieldErrors) = _deriveBlocking(
      updatedDraft,
    );
    state = current.copyWith(
      formData: updatedDraft,
      selectedVenueCategory: value,
      privateVenueWarning: warning,
      // Clear the nudge once a chip is selected.
      venueCategoryNudge: false,
      blockingFields: blockingFields,
      blockingFieldErrors: blockingFieldErrors,
    );
    _scheduleAutosave(updatedDraft);
  }

  /// Called on every keystroke in the venue name text field.
  ///
  /// Delegates the existing field-update path for 'venueName' and recomputes
  /// the private-venue warning against the new text.
  void onVenueNameChanged(String text) {
    // Reuse the existing updateField path for draft mutation + validation.
    updateField(field: 'venueName', value: text.isEmpty ? null : text);

    // Recompute warning after the state has been updated by updateField.
    final current = state;
    if (current is! CreateEventEditing) return;
    final warning = _computeWarning(
      current.selectedVenueCategory,
      text,
    );
    state = current.copyWith(privateVenueWarning: warning);
  }

  /// Compute the [PrivateVenueWarning] variant for the given inputs.
  ///
  /// Reads [myCapabilitiesProvider] synchronously (AsyncValue — does not trigger
  /// a network call; the provider is a FutureProvider that caches its result).
  PrivateVenueWarning _computeWarning(
    String? categoryValue,
    String venueName,
  ) {
    final detection = detectPrivateVenue(
      categoryValue: categoryValue,
      venueName: venueName,
    );

    if (!detection.isPrivate) return const PrivateVenueWarningNone();

    // Determine which warning variant based on the user's capabilities.
    final capsAsync = ref.read(myCapabilitiesProvider);
    return capsAsync.when(
      data: (caps) => caps.canPostPrivateVenue
          ? const PrivateVenueWarningEstablishedHost()
          : const PrivateVenueWarningFirstTimeHost(),
      // Loading or error → first-time-host warning (safer default).
      loading: () => const PrivateVenueWarningFirstTimeHost(),
      error: (_, __) => const PrivateVenueWarningFirstTimeHost(),
    );
  }

  /// Surfaces the venue-category nudge when the user hits Next without
  /// having selected a chip. Called by the Step 2 page on next-tap.
  /// Does NOT block navigation.
  void showVenueCategoryNudge() {
    final current = state;
    if (current is! CreateEventEditing) return;
    if (current.selectedVenueCategory != null) return;
    state = current.copyWith(venueCategoryNudge: true);
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
  /// this method for steps 0–3.
  ///
  /// Derived from [blockingFields] on the current state — any time-dependent
  /// validator (e.g. [validateStartsAt]) is re-evaluated fresh on each call.
  bool canAdvance(int step) {
    final current = state;
    if (current is! CreateEventEditing) return false;
    return !current.blockingFields.containsKey(step);
  }

  /// Returns true iff every field across every step is valid. This is the
  /// single source of truth for "is the form ready to publish" and is used
  /// to gate the Publish button on step 4 — distinct from [canAdvance(4)]
  /// which only validates step 4's own fields.
  ///
  /// Derived from [blockingFields.isEmpty] — re-evaluates time-dependent
  /// validators each time the state is read.
  bool canSubmit() {
    final current = state;
    if (current is! CreateEventEditing) return false;
    return current.blockingFields.isEmpty;
  }

  /// Force a state emission so [blockingFields] re-evaluates against current
  /// wall-clock time. Call this when Step 5 becomes visible (page resume or
  /// build) so that time-decayed [validateStartsAt] is caught before the user
  /// taps Publish.
  ///
  /// This is the correct lifecycle hook — not a timer. The emission is a no-op
  /// in terms of data change if nothing has actually decayed.
  ///
  /// TODO(TRI-55): once the Clock port lands, inject it here and remove the
  /// implicit [DateTime.now()] dependency from [_deriveBlocking].
  void refreshBlockingFields() {
    final current = state;
    if (current is! CreateEventEditing) return;
    final (:blockingFields, :blockingFieldErrors) = _deriveBlocking(
      current.formData,
    );
    state = current.copyWith(
      blockingFields: blockingFields,
      blockingFieldErrors: blockingFieldErrors,
    );
  }

  void goToStep(int step) {
    final current = state;
    if (current is! CreateEventEditing) return;
    assert(step >= 0 && step <= 4, 'step must be in range 0–4');
    // Recompute blockingFields on every step transition so time-dependent
    // validators (currently only validateStartsAt) re-evaluate against current
    // wall-clock time. This catches the case where the user advances through
    // early steps and startsAt decays past the 5-minute buffer while they linger.
    final (:blockingFields, :blockingFieldErrors) = _deriveBlocking(
      current.formData,
    );
    state = current.copyWith(
      formData: current.formData.copyWith(currentStep: step),
      currentStep: step,
      blockingFields: blockingFields,
      blockingFieldErrors: blockingFieldErrors,
    );
  }

  void nextStep() {
    // Dismiss keyboard before any state mutation so focus is always released
    // regardless of the call site (nav bar, test code, etc.).
    FocusManager.instance.primaryFocus?.unfocus();
    final current = state;
    if (current is! CreateEventEditing) return;
    if (current.currentStep < 4) {
      // On Step 2 (venue, index 1), surface the chip nudge if no category was
      // chosen. Non-blocking — navigation proceeds regardless.
      if (current.currentStep == 1) showVenueCategoryNudge();
      goToStep(current.currentStep + 1);
    }
  }

  void previousStep() {
    // Dismiss keyboard before any state mutation so focus is always released
    // regardless of the call site (nav bar, test code, etc.).
    FocusManager.instance.primaryFocus?.unfocus();
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

    // Defense-in-depth: if any required field is null (a UI gating bug bypassed
    // canSubmit), surface a recoverable error instead of throwing in release
    // mode where asserts are stripped. Return to the first step with a null
    // field so the user can see the problem.
    (int, String)? nullField;
    outer:
    for (final entry in _stepFields.entries) {
      for (final field in entry.value) {
        if (_draftFieldIsNull(field, draft)) {
          nullField = (entry.key, field);
          break outer;
        }
      }
    }
    if (nullField != null) {
      state = CreateEventSubmissionError(
        formData: draft,
        failure: const ValidationFailure(
          'Please complete all steps before publishing.',
        ),
        returnToStep: nullField.$1,
        fieldErrors: const {
          '_banner': 'Please complete all steps before publishing.',
        },
      );
      return;
    }

    final params = CreateEventParams(
      title: draft.title!,
      category: draft.category!,
      venueName: draft.venueName!,
      // venueCategory may be null when the user hasn't selected one yet
      // (pre-Brief 9). Fallback to empty string so the server returns a
      // validation error with a clear message rather than crashing the client.
      venueCategory: draft.venueCategory ?? '',
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
      (failure) async =>
          _handleSubmitFailure(failure, draft, current.currentStep),
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
        <String, String?>{'_banner': "You're offline. Please try again."},
      ),
      _ => (currentStep, <String, String?>{'_banner': failure.message}),
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
    const freshDraft = EventDraft();
    final (:blockingFields, :blockingFieldErrors) = _deriveBlocking(freshDraft);
    state = CreateEventEditing(
      formData: freshDraft,
      currentStep: 0,
      fieldErrors: const {},
      isResuming: false,
      blockingFields: blockingFields,
      blockingFieldErrors: blockingFieldErrors,
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
