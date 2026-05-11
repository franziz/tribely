import '../../domain/repositories/user_profile_repository.dart';

class UpdateProfileParamsModel {
  const UpdateProfileParamsModel({
    this.bio,
    this.avatarUrl,
    this.languages,
    this.interests,
    this.currentCity,
    this.travelerType,
  });

  factory UpdateProfileParamsModel.fromDomain(UpdateProfileParams params) =>
      UpdateProfileParamsModel(
        bio: params.bio,
        avatarUrl: params.avatarUrl,
        languages: params.languages,
        interests: params.interests,
        currentCity: params.currentCity,
        travelerType: params.travelerType,
      );

  final String? bio;
  final String? avatarUrl;
  final List<String>? languages;
  final List<String>? interests;
  final String? currentCity;
  final String? travelerType;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (bio != null) json['bio'] = bio;
    if (avatarUrl != null) json['avatarUrl'] = avatarUrl;
    if (languages != null) json['languages'] = languages;
    if (interests != null) json['interests'] = interests;
    if (currentCity != null) json['currentCity'] = currentCity;
    if (travelerType != null) json['travelerType'] = travelerType;
    return json;
  }
}
