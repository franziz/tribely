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
  const UserCapabilities({
    required this.canPostPrivateVenue,
    required this.safetyReminderSeen,
  });

  /// Convenience constructor for the safer no-capability fallback.
  /// Used when the capabilities endpoint is unreachable.
  const UserCapabilities.restricted()
    : canPostPrivateVenue = false,
      safetyReminderSeen = false;

  /// When false, the user must use a public venue for their events
  /// (first-event policy — TRI-33). When true, private venue categories
  /// (apartment, condo, etc.) are allowed.
  final bool canPostPrivateVenue;

  /// When true, the user has already seen (and dismissed) the pre-event safety
  /// reminder for the current session. Flipped locally via [copyWith] so the
  /// reminder is not re-shown within the same session (TRI-34).
  final bool safetyReminderSeen;

  /// Returns a copy of this [UserCapabilities] with selected fields replaced.
  UserCapabilities copyWith({
    bool? canPostPrivateVenue,
    bool? safetyReminderSeen,
  }) {
    return UserCapabilities(
      canPostPrivateVenue: canPostPrivateVenue ?? this.canPostPrivateVenue,
      safetyReminderSeen: safetyReminderSeen ?? this.safetyReminderSeen,
    );
  }

  @override
  List<Object?> get props => [canPostPrivateVenue, safetyReminderSeen];
}
