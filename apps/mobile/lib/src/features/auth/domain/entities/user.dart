import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.emailVerifiedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Null until the user verifies their email via the 6-digit code flow.
  /// `isEmailVerified` is the convenient predicate for UI gating.
  final DateTime? emailVerifiedAt;

  bool get isEmailVerified => emailVerifiedAt != null;

  User copyWith({DateTime? emailVerifiedAt, DateTime? updatedAt}) => User(
    id: id,
    email: email,
    displayName: displayName,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
  );

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    createdAt,
    updatedAt,
    emailVerifiedAt,
  ];
}
