import 'package:equatable/equatable.dart';

/// A record that user [initiatorUserId] has blocked [blockedUserId].
///
/// Immutable value object — no business logic; state changes are surfaced via
/// the repository and use cases.
class UserBlock extends Equatable {
  const UserBlock({
    required this.id,
    required this.initiatorUserId,
    required this.blockedUserId,
    required this.createdAt,
  });

  final String id;
  final String initiatorUserId;
  final String blockedUserId;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, initiatorUserId, blockedUserId, createdAt];
}
