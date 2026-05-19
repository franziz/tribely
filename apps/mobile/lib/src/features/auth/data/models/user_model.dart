import '../../../../features/users/domain/value_objects/selfie_failure_category.dart';
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
    this.selfieStatus = 'notStarted',
    this.selfieAttemptCount = 0,
    this.selfieLastFailureCategory,
    this.selfieAppealLockedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final emailVerified = json['emailVerifiedAt'];
    final phoneVerified = json['phoneVerifiedAt'];
    final appealLockedAt = json['selfie_appeal_locked_at'];
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
      selfieStatus: json['selfie_status'] as String? ?? 'notStarted',
      selfieAttemptCount: json['selfie_attempt_count'] as int? ?? 0,
      selfieLastFailureCategory: SelfieFailureCategory.fromJson(
        json['selfie_last_failure_category'] as String?,
      ),
      selfieAppealLockedAt: appealLockedAt is String
          ? DateTime.parse(appealLockedAt)
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
  final String selfieStatus;
  final int selfieAttemptCount;
  final SelfieFailureCategory? selfieLastFailureCategory;
  final DateTime? selfieAppealLockedAt;

  User toEntity() => User(
    id: id,
    email: email,
    displayName: displayName,
    createdAt: createdAt,
    updatedAt: updatedAt,
    emailVerifiedAt: emailVerifiedAt,
    phoneVerifiedAt: phoneVerifiedAt,
    selfieStatus: selfieStatus,
    selfieAttemptCount: selfieAttemptCount,
    selfieLastFailureCategory: selfieLastFailureCategory,
    selfieAppealLockedAt: selfieAppealLockedAt,
  );
}
