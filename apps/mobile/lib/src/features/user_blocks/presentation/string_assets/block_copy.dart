/// Verbatim copy SoT for the user_blocks feature.
///
/// All user-visible strings are centralized here so Designer edits to copy
/// propagate consistently. Do not inline copy into widget files.
abstract final class BlockCopy {
  // ---------------------------------------------------------------------------
  // Block confirm sheet
  // ---------------------------------------------------------------------------

  static const String blockConfirmTitle = 'Block this user?';

  static const List<String> blockConsequenceBullets = [
    "They won't be able to see your profile or events.",
    "You won't see theirs.",
    'Any pending or upcoming join requests between you will be cancelled.',
    'Past completed events will show them as "Former participant."',
    'You can unblock anytime from Settings > Privacy & Safety > Blocked Users.',
    'Unblocking does not restore cancelled requests.',
  ];

  // ---------------------------------------------------------------------------
  // SnackBar shown after a successful block
  // ---------------------------------------------------------------------------

  /// Returns the post-block success SnackBar message with [displayName]
  /// substituted in. Example: "Maya Tan has been blocked. You can manage
  /// blocked users in Settings."
  static String blockSuccess(String displayName) =>
      '$displayName has been blocked. You can manage blocked users in Settings.';

  // ---------------------------------------------------------------------------
  // Unblock confirmation dialog
  // ---------------------------------------------------------------------------

  /// Returns the unblock dialog title with [name] substituted.
  /// Example: "Unblock Maya Tan?"
  static String unblockDialogTitle(String name) => 'Unblock $name?';

  static const String unblockDialogBody =
      "They'll be able to see your profile and events again.";

  static const String unblockDialogCancel = 'Cancel';
  static const String unblockDialogConfirm = 'Unblock';

  // ---------------------------------------------------------------------------
  // Former participant placeholder
  // ---------------------------------------------------------------------------

  static const String formerParticipant = 'Former participant';

  // ---------------------------------------------------------------------------
  // Blocked Users page — empty state
  // ---------------------------------------------------------------------------

  static const String emptyStateTitle = 'No blocked users';
  static const String emptyStateSubtitle =
      "When you block someone, they'll appear here.";

  // ---------------------------------------------------------------------------
  // Fallback display name when profile fetch failed
  // ---------------------------------------------------------------------------

  static const String unknownUser = 'Unknown user';
}
