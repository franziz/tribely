import '../../domain/entities/user_profile.dart';

class UserProfileModel {
  const UserProfileModel({
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

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final verified = json['emailVerifiedAt'];
    return UserProfileModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      emailVerifiedAt: verified is String ? DateTime.parse(verified) : null,
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      languages: (json['languages'] as List<dynamic>? ?? []).cast<String>(),
      interests: (json['interests'] as List<dynamic>? ?? []).cast<String>(),
      currentCity: json['currentCity'] as String?,
      travelerType: json['travelerType'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

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

  UserProfile toEntity() => UserProfile(
    id: id,
    email: email,
    displayName: displayName,
    createdAt: createdAt,
    updatedAt: updatedAt,
    emailVerifiedAt: emailVerifiedAt,
    bio: bio,
    avatarUrl: avatarUrl,
    languages: languages,
    interests: interests,
    currentCity: currentCity,
    travelerType: travelerType,
    isVerified: isVerified,
  );
}
