import 'dart:typed_data';

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

  /// Uploads a new avatar for the current user via the presign → PUT → confirm
  /// three-step flow.
  ///
  /// [bytes] must be JPEG-encoded (≤512×512 px, Q85 — enforced by the picker).
  ///
  /// Returns the confirmed [UserProfile] (with the new signed avatarUrl) on
  /// success, or a typed [Failure] on any of the three steps:
  ///   - Presign failure → [ServerFailure] / [NetworkFailure]
  ///   - PUT failure     → [ServerFailure] / [NetworkFailure]
  ///   - Confirm failure → [ServerFailure] / [NetworkFailure]
  ///
  /// No retry/backoff in v1 — a single attempt per call; the caller re-taps
  /// on failure.
  Future<Either<Failure, UserProfile>> uploadAvatar(Uint8List bytes);
}
