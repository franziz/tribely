import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_profile.dart';

class UpdateProfileParams extends Equatable {
  const UpdateProfileParams({
    this.bio,
    this.avatarUrl,
    this.languages,
    this.interests,
    this.currentCity,
    this.travelerType,
  });

  final String? bio;
  final String? avatarUrl;
  final List<String>? languages;
  final List<String>? interests;
  final String? currentCity;
  final String? travelerType;

  @override
  List<Object?> get props => [
    bio,
    avatarUrl,
    languages,
    interests,
    currentCity,
    travelerType,
  ];
}

abstract class UserProfileRepository {
  /// Fetches any user's profile by their ID.
  Future<Either<Failure, UserProfile>> getUserProfile(String id);
  Future<Either<Failure, UserProfile>> updateMyProfile(
    UpdateProfileParams params,
  );
}
