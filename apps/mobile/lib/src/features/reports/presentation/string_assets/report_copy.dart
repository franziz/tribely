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

  /// Persistent post-submit confirmation sheet (TRI-164 — ReportReceivedSheet).
  /// Replaces the prior SnackBar surface — SLA is now displayed inline,
  /// not behind a tap, and the sheet includes a link to the Help Centre
  /// article (/help/article/report-faq).
  ///
  /// Numerical coupling: the SLA figures ("72 hours", "7 days") MUST stay
  /// aligned with help_centre_copy.dart and docs/runbooks/moderation-cli.md §2.
  static const String sheetHeadline = 'Report received';

  static const String sheetBodyParagraph1 =
      'Thank you for letting us know. We take every report seriously and review each one individually.';

  static const String sheetBodyParagraph2Sla =
      'We aim to review reports within 72 hours, and resolve within 7 days.';

  static const String sheetPrimaryCta = 'Done';

  static const String sheetSecondaryLink = 'Learn what happens next';

  /// Prompt text shown in the "Also block?" bottom sheet.
  static const String blockOptInPrompt =
      'Also block this user? They won\'t see you on Tribely and you won\'t '
      'see them. Any pending or upcoming join requests between you will be '
      'cancelled.';
}
