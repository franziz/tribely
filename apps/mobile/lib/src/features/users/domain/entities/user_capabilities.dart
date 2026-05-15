import 'package:equatable/equatable.dart';

/// Capability flags for the currently-authenticated user.
///
/// Fetched from `GET /users/me/capabilities` once per session. Stable
/// per-session — capabilities change only on server-side admin action or after
/// the user's first event is published, neither of which can happen mid-session
/// in normal flows.
///
/// Default-safe: when the server is unreachable, callers should fall back to
/// [UserCapabilities.restricted] so first-time-host warnings are shown rather
/// than silently bypassed.
class UserCapabilities extends Equatable {
  const UserCapabilities({required this.canPostPrivateVenue});

  /// Convenience constructor for the safer no-capability fallback.
  /// Used when the capabilities endpoint is unreachable.
  const UserCapabilities.restricted() : canPostPrivateVenue = false;

  /// When false, the user must use a public venue for their events
  /// (first-event policy — TRI-33). When true, private venue categories
  /// (apartment, condo, etc.) are allowed.
  final bool canPostPrivateVenue;

  @override
  List<Object?> get props => [canPostPrivateVenue];
}
