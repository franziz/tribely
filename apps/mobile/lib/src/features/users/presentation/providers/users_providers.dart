import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_reader_riverpod.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../../domain/usecases/get_my_profile_usecase.dart';
import '../../domain/usecases/get_user_profile_usecase.dart';
import '../../domain/usecases/update_my_profile_usecase.dart';
import '../controllers/edit_profile_controller.dart';
import '../controllers/my_profile_controller.dart';
import '../controllers/user_profile_controller.dart';
import '../state/edit_profile_state.dart';
import '../state/user_profile_state.dart';

// --- Use cases ---

// Presentation-layer providers wire dependencies from Ref, not sl<T>(),
// when the use case depends on Riverpod-backed ports (e.g. SessionReader).
/// Constructed inline (not via get_it) because [GetMyProfileUseCase] depends on
/// [sessionReaderProvider], which requires a [Ref] — unavailable at get_it
/// registration time (before [ProviderScope] exists).
final getMyProfileUseCaseProvider = Provider<GetMyProfileUseCase>(
  (ref) => GetMyProfileUseCase(
    sl<UserProfileRepository>(),
    ref.read(sessionReaderProvider),
  ),
);

final getUserProfileUseCaseProvider = Provider<GetUserProfileUseCase>(
  (_) => sl<GetUserProfileUseCase>(),
);

final updateMyProfileUseCaseProvider = Provider<UpdateMyProfileUseCase>(
  (_) => sl<UpdateMyProfileUseCase>(),
);

/// Provides the currently loaded own-profile entity to seed the edit form.
/// Returns null when the profile hasn't loaded yet.
final seedProfileProvider = Provider<UserProfile?>((ref) {
  final state = ref.watch(myProfileControllerProvider);
  return switch (state) {
    UserProfileLoaded(:final profile) => profile,
    _ => null,
  };
});

// --- Controllers ---

final myProfileControllerProvider =
    NotifierProvider<MyProfileController, UserProfileState>(
      MyProfileController.new,
    );

final userProfileControllerProvider =
    NotifierProvider.family<UserProfileController, UserProfileState, String>(
      UserProfileController.new,
    );

final editProfileControllerProvider =
    NotifierProvider<EditProfileController, EditProfileState>(
      EditProfileController.new,
    );
