import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/event_draft.dart';

// ---------------------------------------------------------------------------
// PrivateVenueWarning — sealed warning state for Step 2 venue detection.
// Inline here because it is tightly coupled to [CreateEventEditing] and does
// not form an independent bounded concept that warrants its own file.
// ---------------------------------------------------------------------------

/// Warning level for the private-venue inline banner on Step 2.
///
/// Computed by [CreateEventController] on every `selectVenueCategory` /
/// `onVenueNameChanged` call using the mobile-mirror detection from
/// [detectPrivateVenue] and the user's [myCapabilitiesProvider] state.
sealed class PrivateVenueWarning {
  const PrivateVenueWarning();
}

/// No private-venue signal detected. Banner is hidden.
final class PrivateVenueWarningNone extends PrivateVenueWarning {
  const PrivateVenueWarningNone();
}

/// User has not yet earned private-venue access.
/// Copy: "Tribely events meet in public. Your first event must be at a public
/// spot like a cafe, park, or hawker centre."
final class PrivateVenueWarningFirstTimeHost extends PrivateVenueWarning {
  const PrivateVenueWarningFirstTimeHost();
}

/// User has earned private-venue access but is using a private location.
/// Copy: "Public spots get more joiners. Private venues are allowed but
/// discouraged."
final class PrivateVenueWarningEstablishedHost extends PrivateVenueWarning {
  const PrivateVenueWarningEstablishedHost();
}

// ---------------------------------------------------------------------------
// PublishRejection — sealed signal for server-side publish rejections.
// Inline here because it is tightly coupled to [CreateEventEditing] and does
// not form an independent bounded concept that warrants its own file.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// FirstEventMustBePublicModalResult — result enum for the publish-rejection
// modal. Declared here (alongside PublishRejection) so the controller can
// reference it without importing a widget file. The widget imports it from
// this location too, keeping the dependency direction clean:
//   state/ ← controller ← widget
// (widget imports state, not the other way around).
// ---------------------------------------------------------------------------

/// The user's choice after the "First event must be public" rejection modal.
///
/// Passed to [CreateEventController.onPublishRejectionAcknowledged] so the
/// controller can branch without knowing anything about the widget tree.
///   - [pickPublicPlace]: controller navigates back to Step 2, clears venue.
///   - [cancel]: controller stays on Step 5; host can retry without re-entry.
enum FirstEventMustBePublicModalResult { pickPublicPlace, cancel }

/// Signals that the most recent [CreateEventController.submit] call was
/// rejected by the server with a domain-specific failure that requires a
/// modal acknowledgment before the user can retry.
///
/// Null on [CreateEventEditing] means no rejection is pending.
sealed class PublishRejection {
  const PublishRejection();
}

/// 422 FIRST_EVENT_MUST_BE_PUBLIC. The server rejected the event because the
/// user's first event must use a public venue category. The modal routes the
/// user back to Step 2 to pick a public place, or lets them cancel and retry.
final class PublishRejectionFirstEventMustBePublic extends PublishRejection {
  const PublishRejectionFirstEventMustBePublic();
}

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
    this.blockingFields = const {},
    this.blockingFieldErrors = const {},
    this.selectedVenueCategory,
    this.privateVenueWarning = const PrivateVenueWarningNone(),
    this.venueCategoryNudge = false,
    this.publishRejection,
    this.coverPhotoUploading = false,
    this.coverPhotoProgress,
    this.coverPhotoError,
    this.coverPhotoLocalBytes,
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

  /// Step index → list of field names that currently fail validation.
  ///
  /// Derived fresh on every state emission — never stale. An empty map means
  /// every field across every step is valid (the form is publishable).
  ///
  /// Time-dependent validators (currently only `validateStartsAt`) re-run on
  /// every state emission triggered by [CreateEventController.goToStep],
  /// [nextStep], [previousStep], and [refreshBlockingFields] — so the race
  /// where the user lingers on later steps while startsAt decays past the
  /// 5-minute buffer is caught at every step transition.
  final Map<int, List<String>> blockingFields;

  /// Step index → list of (fieldName, errorMessage) pairs for fields that
  /// currently fail validation. Parallel to [blockingFields] — carries the
  /// human-readable error strings so the UI can render them without calling
  /// back into the controller.
  final Map<int, List<(String, String)>> blockingFieldErrors;

  /// The raw snake_case venue category currently selected via the chip grid
  /// on Step 2. Mirrors [EventDraft.venueCategory]; kept as a separate field
  /// so the chip grid can render selection state from the controller state
  /// without going through the draft DTO.
  final String? selectedVenueCategory;

  /// Current warning level for the private-venue inline banner on Step 2.
  /// Recomputed whenever [selectedVenueCategory] or the venue name text
  /// changes.
  final PrivateVenueWarning privateVenueWarning;

  /// When true, the Step 2 page renders a non-blocking inline nudge near the
  /// chip grid ("Pick a venue type"). Set on [nextStep] when no chip has been
  /// selected yet. Cleared automatically when a chip is selected.
  final bool venueCategoryNudge;

  /// Non-null when the most recent [CreateEventController.submit] call was
  /// rejected by the server with a domain-specific failure that requires a
  /// modal acknowledgment. The Step 5 page watches this field and shows the
  /// appropriate modal when it becomes non-null. Call
  /// [CreateEventController.onPublishRejectionAcknowledged] to clear it.
  final PublishRejection? publishRejection;

  // ---------------------------------------------------------------------------
  // Cover-photo upload state (Step 0)
  // ---------------------------------------------------------------------------

  /// True while the cover photo PUT is in-flight. Drives the
  /// [LinearProgressIndicator] and hides the "Change photo" affordance.
  final bool coverPhotoUploading;

  /// Upload progress as a fraction 0.0–1.0. Non-null and determinate while
  /// [coverPhotoUploading] is true and the storage PUT has reported progress.
  /// Null if no progress has been received yet (indeterminate phase).
  final double? coverPhotoProgress;

  /// Non-null when the most recent cover-photo upload attempt failed. Carries
  /// the [Failure] so Step 0 can branch on validation vs. network errors.
  ///   - [ValidationFailure]: size/MIME error — re-pick required (no Retry).
  ///   - Other failures: Retry path (re-uses [coverPhotoLocalBytes]).
  final Failure? coverPhotoError;

  /// The cropped bytes from the most recent successful crop, kept in state so
  /// upload can be retried without re-cropping on transient failures. Cleared
  /// when the upload succeeds (key is written to [EventDraft.coverPhotoStorageKey]).
  final Uint8List? coverPhotoLocalBytes;

  // Sentinel token for the nullable [selectedVenueCategory] copyWith param.
  // Using a private static const avoids the "const Object()" problem — the
  // bool is a primitive constant that doesn't conflict with any valid value.
  static const _unsetVenueCategory = '_unset_';

  // Sentinel token for the nullable [publishRejection] copyWith param.
  // A static const avoids allocating a new object on every copyWith call.
  static const Object _unsetPublishRejection = Object();

  // Sentinel tokens for the nullable cover-photo upload fields. Each requires
  // its own typed sentinel so copyWith callers can pass explicit null to clear.
  static const Object _unsetCoverPhotoProgress = Object();
  static const Object _unsetCoverPhotoError = Object();
  static const Object _unsetCoverPhotoLocalBytes = Object();

  CreateEventEditing copyWith({
    EventDraft? formData,
    int? currentStep,
    Map<String, String?>? fieldErrors,
    bool? isResuming,
    Map<int, List<String>>? blockingFields,
    Map<int, List<(String, String)>>? blockingFieldErrors,
    // Use a sentinel String so callers can explicitly pass null to clear
    // the selection. Passing nothing → preserve current value.
    String? selectedVenueCategory = _unsetVenueCategory,
    PrivateVenueWarning? privateVenueWarning,
    bool? venueCategoryNudge,
    // Use a sentinel Object so callers can explicitly pass null to clear
    // the rejection. Passing nothing → preserve current value.
    Object? publishRejection = _unsetPublishRejection,
    bool? coverPhotoUploading,
    Object? coverPhotoProgress = _unsetCoverPhotoProgress,
    Object? coverPhotoError = _unsetCoverPhotoError,
    Object? coverPhotoLocalBytes = _unsetCoverPhotoLocalBytes,
  }) => CreateEventEditing(
    formData: formData ?? this.formData,
    currentStep: currentStep ?? this.currentStep,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    isResuming: isResuming ?? this.isResuming,
    blockingFields: blockingFields ?? this.blockingFields,
    blockingFieldErrors: blockingFieldErrors ?? this.blockingFieldErrors,
    selectedVenueCategory: selectedVenueCategory == _unsetVenueCategory
        ? this.selectedVenueCategory
        : selectedVenueCategory,
    privateVenueWarning: privateVenueWarning ?? this.privateVenueWarning,
    venueCategoryNudge: venueCategoryNudge ?? this.venueCategoryNudge,
    publishRejection: publishRejection == _unsetPublishRejection
        ? this.publishRejection
        : publishRejection as PublishRejection?,
    coverPhotoUploading: coverPhotoUploading ?? this.coverPhotoUploading,
    coverPhotoProgress: coverPhotoProgress == _unsetCoverPhotoProgress
        ? this.coverPhotoProgress
        : coverPhotoProgress as double?,
    coverPhotoError: coverPhotoError == _unsetCoverPhotoError
        ? this.coverPhotoError
        : coverPhotoError as Failure?,
    coverPhotoLocalBytes: coverPhotoLocalBytes == _unsetCoverPhotoLocalBytes
        ? this.coverPhotoLocalBytes
        : coverPhotoLocalBytes as Uint8List?,
  );

  @override
  List<Object?> get props => [
    formData,
    currentStep,
    fieldErrors,
    isResuming,
    blockingFields,
    blockingFieldErrors,
    selectedVenueCategory,
    privateVenueWarning,
    venueCategoryNudge,
    publishRejection,
    coverPhotoUploading,
    coverPhotoProgress,
    coverPhotoError,
    coverPhotoLocalBytes,
  ];
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
