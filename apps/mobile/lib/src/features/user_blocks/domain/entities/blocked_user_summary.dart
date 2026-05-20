import 'package:equatable/equatable.dart';

/// A denormalised summary of a blocked user, enriched with display data so the
/// Blocked Users page can render rows without a second network hop per row.
///
/// The backend [GET /me/blocks] returns only [blockedUserId]; display data
/// ([displayName], [avatarUrl]) is fetched per-row via [GET /users/:id] in
/// the repository implementation.
class BlockedUserSummary extends Equatable {
  const BlockedUserSummary({
    required this.blockId,
    required this.blockedUserId,
    required this.createdAt,
    this.displayName,
    this.avatarUrl,
  });

  final String blockId;
  final String blockedUserId;
  final DateTime createdAt;

  /// Display name — null when the profile fetch fails (row still renders with
  /// a fallback "Unknown user" label).
  final String? displayName;

  /// Avatar URL — null when the profile fetch fails (row renders a grey
  /// placeholder circle).
  final String? avatarUrl;

  @override
  List<Object?> get props => [
    blockId,
    blockedUserId,
    createdAt,
    displayName,
    avatarUrl,
  ];
}
