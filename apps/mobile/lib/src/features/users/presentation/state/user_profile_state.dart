import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_profile.dart';

sealed class UserProfileState extends Equatable {
  const UserProfileState();

  @override
  List<Object?> get props => [];
}

class UserProfileLoading extends UserProfileState {
  const UserProfileLoading();
}

class UserProfileLoaded extends UserProfileState {
  const UserProfileLoaded(this.profile);
  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

class UserProfileError extends UserProfileState {
  const UserProfileError({required this.failure, required this.message});
  final Failure failure;
  final String message;

  @override
  List<Object?> get props => [failure, message];
}
