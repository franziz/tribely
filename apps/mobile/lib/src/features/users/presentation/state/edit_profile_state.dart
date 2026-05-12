import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_profile.dart';

sealed class EditProfileState extends Equatable {
  const EditProfileState();

  @override
  List<Object?> get props => [];
}

class EditProfileIdle extends EditProfileState {
  const EditProfileIdle(this.profile);
  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

class EditProfileSaving extends EditProfileState {
  const EditProfileSaving(this.profile);
  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

class EditProfileSaved extends EditProfileState {
  const EditProfileSaved(this.profile);
  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

class EditProfileError extends EditProfileState {
  const EditProfileError({
    required this.profile,
    required this.failure,
    required this.message,
    this.fieldErrors = const {},
  });

  final UserProfile profile;
  final Failure failure;
  final String message;

  /// Field-level validation errors keyed by field name (e.g. 'bio', 'currentCity').
  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [profile, failure, message, fieldErrors];
}
