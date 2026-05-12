import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/wiring/session_reader_riverpod.dart';
import '../../../../core/di/service_locator.dart';
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

// --- Infrastructure bridge ---

/// Lifts [UserProfileRepository] (registered in get_it) into the Riverpod
/// graph so all use-case providers can resolve it uniformly via [ref].
final _userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (_) => sl<UserProfileRepository>(),
);

// --- Use cases ---

/// All three use-case providers share the same shape: construct inline using
/// [ref.read] so dependencies are resolved through the Riverpod graph. This
/// avoids mixing [sl] and [ref] within a single provider.
final getMyProfileUseCaseProvider = Provider<GetMyProfileUseCase>(
  (ref) => GetMyProfileUseCase(
    ref.read(_userProfileRepositoryProvider),
    ref.read(sessionReaderProvider),
  ),
);

final getUserProfileUseCaseProvider = Provider<GetUserProfileUseCase>(
  (ref) => GetUserProfileUseCase(ref.read(_userProfileRepositoryProvider)),
);

final updateMyProfileUseCaseProvider = Provider<UpdateMyProfileUseCase>(
  (ref) => UpdateMyProfileUseCase(ref.read(_userProfileRepositoryProvider)),
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
