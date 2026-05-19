import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
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

  bool get isEmailVerified => emailVerifiedAt != null;
  bool get isPhoneVerified => phoneVerifiedAt != null;

  User copyWith({
    DateTime? emailVerifiedAt,
    DateTime? updatedAt,
    // Use Object? sentinel to distinguish "set to null" from "leave unchanged".
    Object? phoneVerifiedAt = _sentinel,
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
  ];
}

/// Sentinel used in [User.copyWith] to distinguish "leave unchanged" from
/// "explicitly set to null" for nullable [phoneVerifiedAt].
const Object _sentinel = Object();
