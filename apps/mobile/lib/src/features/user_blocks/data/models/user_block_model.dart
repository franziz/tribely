import '../../domain/entities/user_block.dart';

/// JSON deserialization DTO for a single block row returned by
/// POST /me/blocks (block action) or GET /me/blocks (list action).
///
/// [toEntity] converts to the pure-Dart [UserBlock] domain entity.
class UserBlockModel {
  const UserBlockModel({
    required this.id,
    required this.initiatorUserId,
    required this.blockedUserId,
    required this.createdAt,
  });

  factory UserBlockModel.fromJson(Map<String, dynamic> json) {
    return UserBlockModel(
      id: json['id'] as String,
      initiatorUserId: json['initiatorUserId'] as String,
      blockedUserId: json['blockedUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String initiatorUserId;
  final String blockedUserId;
  final DateTime createdAt;

  UserBlock toEntity() => UserBlock(
    id: id,
    initiatorUserId: initiatorUserId,
    blockedUserId: blockedUserId,
    createdAt: createdAt,
  );
}
