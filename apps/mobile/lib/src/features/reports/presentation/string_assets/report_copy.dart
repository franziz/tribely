/// Verbatim Designer-mandated copy for the report flow.
///
/// This is the single source of truth for all user-visible strings in the
/// report-a-review feature. Do not duplicate these strings elsewhere; import
/// this file and reference the constants directly.
///
/// Copy reviewed and approved against Brief 2B spec.
abstract final class ReportCopy {
  /// Label above the reason radio picker.
  static const String reasonPickerLabel = 'Why are you reporting this review?';

  /// Disclaimer shown between the reason picker and the free-text field.
  static const String disclaimer =
      'We review reports against our Community Standards within 72 hours. '
      'Submitting a false report is itself a violation. We may share your '
      'report with the reviewed user if required by law or to investigate '
      'abuse, but we will not disclose your identity to them by default.';

  /// Post-submit confirmation SnackBar body.
  static const String snackBarConfirmation =
      'Report received. We aim to review within 72 hours and will act if '
      'the review breaches our Community Standards. We don\'t share the '
      'outcome of individual reports, but the review will be hidden if we '
      'remove it.';

  /// Prompt text shown in the "Also block?" bottom sheet.
  static const String blockOptInPrompt =
      'Also block this user? They won\'t see you on Tribely and you won\'t '
      'see them. Any pending or upcoming join requests between you will be '
      'cancelled.';
}
