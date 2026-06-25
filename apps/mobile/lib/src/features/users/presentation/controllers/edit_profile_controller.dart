import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../providers/users_providers.dart';
import '../state/edit_profile_state.dart';
import '../string_assets/avatar_copy.dart';

/// Controller for the Edit Profile page.
///
/// Owns two async flows — profile field save ([save]) and avatar upload
/// ([uploadAvatar]) — **in a single state machine** to enforce a hard
/// mutual-exclusion invariant: neither flow may start while the other is
/// running, and the AppBar Save button is disabled during both.
///
/// **Why one controller, not two?**
/// Splitting [uploadAvatar] into a dedicated `avatarUploadControllerProvider`
/// would require the page to read two providers and OR their in-progress states
/// for the Save-disabled check — a fragile contract that future contributors
/// can easily break by checking only one. Keeping both flows here makes the
/// invariant impossible to violate: the early-return guards in [save] and
/// [uploadAvatar] share the same [state] reference, so they are atomically
/// consistent. Do not extract [uploadAvatar] without re-establishing this
/// invariant in the new controller.
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
    // Block save while saving or while an avatar upload is in progress.
    if (current is EditProfileSaving) return;
    if (current is EditProfileUploadingAvatar) return;
    final profile = switch (current) {
      EditProfileIdle(:final profile) => profile,
      EditProfileError(:final profile) => profile,
      EditProfileSaved(:final profile) => profile,
      EditProfileSaving() => throw StateError('unreachable'),
      EditProfileUploadingAvatar() => throw StateError('unreachable'),
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

  /// Uploads a new avatar from [bytes] (raw JPEG from the picker).
  ///
  /// Guards:
  ///   - If [EditProfileSaving] is active, save wins — upload is a no-op.
  ///   - If [EditProfileUploadingAvatar] is active, the upload is already in
  ///     progress — second call is a no-op.
  ///
  /// On success: invalidates [myProfileControllerProvider] so the profile
  /// header refetches silently, emits [HapticFeedback.lightImpact], and
  /// returns to [EditProfileIdle].
  ///
  /// On failure: transitions to [EditProfileError] with the avatar error copy
  /// from [avatar_copy.dart]. Previous profile is preserved unchanged.
  Future<void> uploadAvatar(Uint8List bytes) async {
    final current = state;
    // Don't race a save or a concurrent upload.
    if (current is EditProfileSaving) return;
    if (current is EditProfileUploadingAvatar) return;

    final profile = switch (current) {
      EditProfileIdle(:final profile) => profile,
      EditProfileError(:final profile) => profile,
      EditProfileSaved(:final profile) => profile,
      EditProfileSaving() => throw StateError('unreachable'),
      EditProfileUploadingAvatar() => throw StateError('unreachable'),
    };

    state = EditProfileUploadingAvatar(profile);

    final useCase = ref.read(uploadAvatarUseCaseProvider);
    final result = await useCase(bytes);

    if (!ref.mounted) return;
    result.match(
      (failure) {
        state = EditProfileError(
          profile: profile,
          failure: failure,
          message: kAvatarUploadErrorMessage,
        );
      },
      (updatedProfile) {
        // Propagate the updated profile (new avatarUrl) into the edit-form
        // state so the control reflects the new avatar immediately.
        state = EditProfileIdle(updatedProfile);
        // Invalidate the profile cache so /profile header refetches silently.
        ref.invalidate(myProfileControllerProvider);
        HapticFeedback.lightImpact();
      },
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
