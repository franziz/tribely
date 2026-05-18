import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.emailVerifiedAt,
    this.bio,
    this.avatarUrl,
    this.languages = const [],
    this.interests = const [],
    this.currentCity,
    this.travelerType,
    this.isVerified = false,
  });

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? emailVerifiedAt;
  final String? bio;
  final String? avatarUrl;
  final List<String> languages;
  final List<String> interests;
  final String? currentCity;
  final String? travelerType;
  final bool isVerified;

  UserProfile copyWith({
    String? bio,
    String? avatarUrl,
    List<String>? languages,
    List<String>? interests,
    String? currentCity,
    String? travelerType,
  }) => UserProfile(
    id: id,
    email: email,
    displayName: displayName,
    createdAt: createdAt,
    updatedAt: updatedAt,
    emailVerifiedAt: emailVerifiedAt,
    bio: bio ?? this.bio,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    languages: languages ?? this.languages,
    interests: interests ?? this.interests,
    currentCity: currentCity ?? this.currentCity,
    travelerType: travelerType ?? this.travelerType,
  );

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    createdAt,
    updatedAt,
    emailVerifiedAt,
    bio,
    avatarUrl,
    languages,
    interests,
    currentCity,
    travelerType,
    isVerified,
  ];
}
