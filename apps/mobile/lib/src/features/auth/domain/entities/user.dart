import 'package:equatable/equatable.dart';

import '../../../users/domain/value_objects/selfie_failure_category.dart';

class User extends Equatable {
  const User({
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

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Null until the user verifies their email via the 6-digit code flow.
  /// `isEmailVerified` is the convenient predicate for UI gating.
  final DateTime? emailVerifiedAt;

  /// Null until the user verifies their phone number via the SMS OTP flow.
  /// `isPhoneVerified` is the convenient predicate for UI gating.
  final DateTime? phoneVerifiedAt;

  /// Selfie verification lifecycle status.
  /// One of: 'notStarted' | 'pending' | 'rejected' | 'approved'.
  final String selfieStatus;

  /// How many times the user has attempted selfie verification.
  final int selfieAttemptCount;

  /// The reason the most recent selfie was rejected, if any.
  final SelfieFailureCategory? selfieLastFailureCategory;

  /// When set, the user is in the appeal-locked window and cannot re-submit
  /// until this timestamp has passed.
  final DateTime? selfieAppealLockedAt;

  bool get isEmailVerified => emailVerifiedAt != null;
  bool get isPhoneVerified => phoneVerifiedAt != null;

  User copyWith({
    DateTime? emailVerifiedAt,
    DateTime? updatedAt,
    // Use Object? sentinel to distinguish "set to null" from "leave unchanged".
    Object? phoneVerifiedAt = _sentinel,
    String? selfieStatus,
    int? selfieAttemptCount,
    Object? selfieLastFailureCategory = _sentinel,
    Object? selfieAppealLockedAt = _sentinel,
  }) => User(
    id: id,
    email: email,
    displayName: displayName,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
    phoneVerifiedAt: phoneVerifiedAt == _sentinel
        ? this.phoneVerifiedAt
        : phoneVerifiedAt as DateTime?,
    selfieStatus: selfieStatus ?? this.selfieStatus,
    selfieAttemptCount: selfieAttemptCount ?? this.selfieAttemptCount,
    selfieLastFailureCategory: selfieLastFailureCategory == _sentinel
        ? this.selfieLastFailureCategory
        : selfieLastFailureCategory as SelfieFailureCategory?,
    selfieAppealLockedAt: selfieAppealLockedAt == _sentinel
        ? this.selfieAppealLockedAt
        : selfieAppealLockedAt as DateTime?,
  );

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    createdAt,
    updatedAt,
    emailVerifiedAt,
    phoneVerifiedAt,
    selfieStatus,
    selfieAttemptCount,
    selfieLastFailureCategory,
    selfieAppealLockedAt,
  ];
}

/// Sentinel used in [User.copyWith] to distinguish "leave unchanged" from
/// "explicitly set to null" for nullable fields.
const Object _sentinel = Object();
