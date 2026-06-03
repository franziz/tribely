/// Copy constants for [SafetyReminderSheet].
///
/// Each reminder is expressed as three properties:
///   - [emoji]         — the emoji glyph rendered as a leading icon.
///   - [copy]          — the body text rendered next to the emoji.
///   - [semanticsLabel] — the merged VoiceOver / TalkBack label for the row.
///
/// These are stored here (rather than inlined in the widget) to mirror the
/// [RemoveAttendeeCopy] precedent and make them easy to update independently
/// of the widget layout.
abstract final class SafetyReminderCopy {
  // ── Sheet header ─────────────────────────────────────────────────────────

  /// Bottom-sheet header headline.
  static const String header = 'Quick check before you head out';

  // ── Reminder rows ─────────────────────────────────────────────────────────

  /// Row 1 — public meeting spot.
  static const String row1Emoji = '📍';
  static const String row1Copy = 'Meet in a public spot';
  static const String row1SemanticsLabel =
      'Location pin. Meet in a public spot';

  /// Row 2 — tell a friend.
  static const String row2Emoji = '👥';
  static const String row2Copy = 'Tell a friend your plans';
  static const String row2SemanticsLabel =
      'Two people. Tell a friend your plans';

  /// Row 3 — trust your gut.
  static const String row3Emoji = '🛑';
  static const String row3Copy = "Trust your gut — it's okay to leave";
  static const String row3SemanticsLabel =
      "Stop sign. Trust your gut — it's okay to leave";

  // ── CTA ───────────────────────────────────────────────────────────────────

  /// Primary CTA label.
  static const String ctaLabel = 'Got it, send my request';
}
