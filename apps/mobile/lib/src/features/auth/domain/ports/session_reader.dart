/// Port: read-only window into the current authentication session.
///
/// Pure Dart — no Flutter, no Riverpod imports. Any feature that needs the
/// current user ID depends on this abstraction, never on
/// `auth/presentation/providers/auth_providers.dart` or
/// `auth/presentation/state/auth_state.dart` directly.
abstract class SessionReader {
  /// The authenticated user's ID, or null when unauthenticated / restoring.
  String? get currentUserId;
}
