import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/datasources/avatar_picker_datasource.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../../domain/usecases/get_user_profile_usecase.dart';
import '../../domain/usecases/update_my_profile_usecase.dart';
import '../../domain/usecases/upload_avatar_usecase.dart';
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

final getUserProfileUseCaseProvider = Provider<GetUserProfileUseCase>(
  (ref) => GetUserProfileUseCase(ref.read(_userProfileRepositoryProvider)),
);

final updateMyProfileUseCaseProvider = Provider<UpdateMyProfileUseCase>(
  (ref) => UpdateMyProfileUseCase(ref.read(_userProfileRepositoryProvider)),
);

final uploadAvatarUseCaseProvider = Provider<UploadAvatarUseCase>(
  (_) => sl<UploadAvatarUseCase>(),
);

final avatarPickerDatasourceProvider = Provider<AvatarPickerDatasource>(
  (_) => sl<AvatarPickerDatasource>(),
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
