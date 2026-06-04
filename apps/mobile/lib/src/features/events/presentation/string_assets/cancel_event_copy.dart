/// Copy constants for [CancelEventSheet] and the host cancel affordance on the
/// event-detail page.
///
/// Zero imports — all values are compile-time constants.
abstract final class CancelEventCopy {
  /// Bottom-sheet headline.
  static const String headline = 'Cancel this event?';

  /// Bottom-sheet body copy (PM-corrected AC2 — verbatim).
  static const String body =
      'This marks the event as cancelled. Anyone who joined will see it as '
      'cancelled in their events. This can\'t be undone.';

  /// Destructive submit button label.
  static const String submitLabel = 'Yes, cancel event';

  /// Dismiss / keep button label.
  static const String dismissLabel = 'Keep event';

  /// Action-sheet item label for the host kebab menu.
  static const String actionSheetLabel = 'Cancel event';

  /// Inline error banner copy shown when the cancel request fails.
  static const String errorMessage =
      "Couldn't cancel the event. Check your connection and try again.";
}
