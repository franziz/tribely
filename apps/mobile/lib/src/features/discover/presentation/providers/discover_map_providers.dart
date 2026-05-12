import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier that tracks whether the location permission rationale sheet
/// has been shown during the current app session. Session-scoped; does
/// not persist across app restarts.
///
/// The spec says "No re-prompt on subsequent Map tab taps" — within a
/// single session this in-memory flag is sufficient. Across sessions the
/// OS permission status is authoritative: if permission was already granted
/// the sheet is skipped entirely (no re-prompt needed).
class LocationPromptShownNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Mark the location permission sheet as shown for this session.
  void markShown() => state = true;
}

final locationPromptShownProvider =
    NotifierProvider<LocationPromptShownNotifier, bool>(
      LocationPromptShownNotifier.new,
    );
