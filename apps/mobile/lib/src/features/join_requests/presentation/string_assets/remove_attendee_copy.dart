/// Copy constants for [RemoveAttendeeSheet].
///
/// All template strings use `{placeholder}` notation — callers must interpolate
/// at render time (e.g., `RemoveAttendeeCopy.title.replaceAll('{firstName}', firstName)`).
abstract final class RemoveAttendeeCopy {
  /// Bottom-sheet title. Interpolate `{firstName}` at render time.
  static const String title = 'Remove {firstName}?';

  /// Sub-head copy (Path B — no verbatim-warning mention).
  /// Interpolate `{eventTitle}` at render time.
  static const String subhead =
      'This will remove them from {eventTitle}. You cannot undo this.';

  /// Text-field hint. Interpolate `{firstName}` at render time.
  static const String fieldHint = 'Add a note for {firstName}';

  /// Submit button label. Interpolate `{firstName}` at render time.
  static const String submitLabel = 'Remove {firstName}';

  /// Cancel button label.
  static const String cancelLabel = 'Cancel';

  /// Discard-confirm dialog title — mirrors decline sheet.
  static const String discardTitle = 'Abandon this note?';

  /// Discard dialog left action (secondary, keep-writing).
  static const String discardKeepWriting = 'Keep Writing';

  /// Discard dialog right action (secondary, confirm discard).
  static const String discardConfirm = 'Discard';

  /// Action-sheet label for the remove option.
  static const String actionSheetRemove = 'Remove from event';

  /// Error fallback toast. Interpolate `{firstName}` at render time.
  static const String errorToast = "Couldn't remove {firstName}. Try again.";

  // ---------------------------------------------------------------------------
  // Character cap + live-region thresholds
  // ---------------------------------------------------------------------------

  /// Maximum reason text length.
  static const int maxLength = 200;

  /// Live-region announce threshold: 50 remaining chars.
  static const int announceAt50 = 50;

  /// Live-region announce threshold: 20 remaining chars.
  static const int announceAt20 = 20;
}
