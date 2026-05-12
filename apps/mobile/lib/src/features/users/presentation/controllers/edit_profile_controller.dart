import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../providers/users_providers.dart';
import '../state/edit_profile_state.dart';

class EditProfileController extends Notifier<EditProfileState> {
  @override
  EditProfileState build() {
    // Seed initial state from the cached own profile if available.
    final profile = ref.read(seedProfileProvider);
    final fallback = UserProfile(
      id: '',
      email: '',
      displayName: '',
      createdAt: DateTime.utc(1970),
      updatedAt: DateTime.utc(1970),
    );
    return EditProfileIdle(profile ?? fallback);
  }

  Future<void> save({
    String? bio,
    String? currentCity,
    List<String>? languages,
    List<String>? interests,
    String? travelerType,
  }) async {
    final current = state;
    if (current is EditProfileSaving) return;
    final profile = switch (current) {
      EditProfileIdle(:final profile) => profile,
      EditProfileError(:final profile) => profile,
      EditProfileSaved(:final profile) => profile,
      EditProfileSaving() => throw StateError('unreachable'),
    };

    state = EditProfileSaving(profile);

    final useCase = ref.read(updateMyProfileUseCaseProvider);
    final params = UpdateProfileParams(
      bio: bio,
      currentCity: currentCity,
      languages: languages,
      interests: interests,
      travelerType: travelerType,
    );
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.match(
      (failure) => EditProfileError(
        profile: profile,
        failure: failure,
        message: _messageFor(failure),
        fieldErrors: _fieldErrorsFor(failure),
      ),
      EditProfileSaved.new,
    );
  }

  /// Transitions from [EditProfileError] back to [EditProfileIdle] so the user
  /// can retry without reloading the page. No-op for other states.
  void clearError() {
    final current = state;
    if (current is EditProfileError) {
      state = EditProfileIdle(current.profile);
    }
  }
}

String _messageFor(Failure failure) => switch (failure) {
  NetworkFailure() => "Couldn't reach Tribely. Check your connection.",
  ValidationFailure(:final message) => message,
  ServerFailure() => 'Something went wrong. Try again.',
  AuthFailure() => 'Please sign in again.',
  _ => failure.message,
};

Map<String, String> _fieldErrorsFor(Failure failure) {
  if (failure is ValidationFailure && failure.fieldErrors != null) {
    return failure.fieldErrors!.map(
      (key, errors) => MapEntry(key, errors.first),
    );
  }
  return const {};
}
