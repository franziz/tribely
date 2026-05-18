import '../../domain/entities/user.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final emailVerified = json['emailVerifiedAt'];
    final phoneVerified = json['phoneVerifiedAt'];
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      emailVerifiedAt: emailVerified is String
          ? DateTime.parse(emailVerified)
          : null,
      phoneVerifiedAt: phoneVerified is String
          ? DateTime.parse(phoneVerified)
          : null,
    );
  }

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? emailVerifiedAt;
  final DateTime? phoneVerifiedAt;

  User toEntity() => User(
    id: id,
    email: email,
    displayName: displayName,
    createdAt: createdAt,
    updatedAt: updatedAt,
    emailVerifiedAt: emailVerifiedAt,
    phoneVerifiedAt: phoneVerifiedAt,
  );
}
