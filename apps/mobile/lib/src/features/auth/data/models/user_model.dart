import '../../domain/entities/user.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.emailVerifiedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final verified = json['emailVerifiedAt'];
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      emailVerifiedAt: verified is String ? DateTime.parse(verified) : null,
    );
  }

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? emailVerifiedAt;

  User toEntity() => User(
    id: id,
    email: email,
    displayName: displayName,
    createdAt: createdAt,
    updatedAt: updatedAt,
    emailVerifiedAt: emailVerifiedAt,
  );
}
