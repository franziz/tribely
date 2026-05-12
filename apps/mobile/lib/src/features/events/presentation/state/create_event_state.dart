import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/event_draft.dart';

/// The complete state surface for the multi-step create-event flow.
///
/// State machine:
///   CreateEventEditing  ─── submit() ───►  CreateEventSubmitting
///   CreateEventSubmitting ─ success ──►  CreateEventSubmissionSuccess
///   CreateEventSubmitting ─ failure ──►  CreateEventSubmissionError
///   CreateEventSubmissionError ─ UI ──►  CreateEventEditing (returnToStep)
sealed class CreateEventState extends Equatable {
  const CreateEventState();
}

/// The primary editing state — the user is filling in the form.
final class CreateEventEditing extends CreateEventState {
  const CreateEventEditing({
    required this.formData,
    required this.currentStep,
    required this.fieldErrors,
    required this.isResuming,
  });

  /// The current form values. All fields start null and are filled as the
  /// user advances through steps.
  final EventDraft formData;

  /// Zero-based step index. Steps 0–4 correspond to:
  ///   0 = title + category
  ///   1 = venue name + lat/lng
  ///   2 = starts at + ends at
  ///   3 = capacity + approval mode
  ///   4 = description
  final int currentStep;

  /// Field-level inline error messages. Key is the field name; value is the
  /// error string, or null when the field passes validation. The special key
  /// `_banner` is reserved for form-level (non-field) error banners surfaced
  /// by [CreateEventSubmissionError] when the controller remaps to editing.
  final Map<String, String?> fieldErrors;

  /// True immediately after a draft has been loaded on init. The page shows
  /// a "Resume your draft?" dialog and calls [CreateEventController.acknowledgeResume]
  /// or [CreateEventController.discardDraft] to clear this flag.
  final bool isResuming;

  CreateEventEditing copyWith({
    EventDraft? formData,
    int? currentStep,
    Map<String, String?>? fieldErrors,
    bool? isResuming,
  }) => CreateEventEditing(
    formData: formData ?? this.formData,
    currentStep: currentStep ?? this.currentStep,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    isResuming: isResuming ?? this.isResuming,
  );

  @override
  List<Object?> get props => [formData, currentStep, fieldErrors, isResuming];
}

/// The form is being submitted to the server. The UI should disable all
/// inputs and show a loading indicator.
final class CreateEventSubmitting extends CreateEventState {
  const CreateEventSubmitting(this.formData);

  final EventDraft formData;

  @override
  List<Object?> get props => [formData];
}

/// Submission failed. The controller has already determined which step
/// owns the offending field(s) so the page can navigate back and surface
/// inline errors.
final class CreateEventSubmissionError extends CreateEventState {
  const CreateEventSubmissionError({
    required this.formData,
    required this.failure,
    required this.returnToStep,
    required this.fieldErrors,
  });

  final EventDraft formData;
  final Failure failure;

  /// The step index the page should navigate back to before displaying
  /// [fieldErrors]. Determined by the first field that failed validation, or
  /// the current step for network/auth failures.
  final int returnToStep;

  /// Field-level errors to render. The special key `_banner` is used for
  /// failures that don't map to a specific input (e.g. network, auth).
  final Map<String, String?> fieldErrors;

  @override
  List<Object?> get props => [formData, failure, returnToStep, fieldErrors];
}

/// Submission succeeded. The controller has already cleared the local draft.
/// The page observes this state and navigates to the event detail screen.
final class CreateEventSubmissionSuccess extends CreateEventState {
  const CreateEventSubmissionSuccess(this.eventId);

  final String eventId;

  @override
  List<Object?> get props => [eventId];
}
