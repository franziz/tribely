import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/service_locator.dart';
import '../../features/users/domain/entities/user_profile.dart';
import '../../features/users/domain/usecases/get_user_profile_usecase.dart';

// ---------------------------------------------------------------------------
// Use case provider — lives in core/providers/ because multiple features
// (discover/join_requests, future search) need to look up a user by id and
// a feature-level provider would force cross-feature presentation imports.
// Follows the browse_events_usecase_provider.dart precedent.
// ---------------------------------------------------------------------------

/// Exposes [GetUserProfileUseCase] from the get_it service locator to Riverpod.
final getUserProfileUseCaseByIdProvider = Provider<GetUserProfileUseCase>(
  (_) => sl<GetUserProfileUseCase>(),
);

/// Async provider: fetch a [UserProfile] by id.
///
/// Throws the domain [Failure] on error (Riverpod wraps it in an [AsyncError]).
/// Callers handle the error state via `AsyncValue.when` or a switch on
/// `AsyncValue`.
///
/// Family key: `userId` string.
final userProfileByIdProvider =
    FutureProvider.autoDispose.family<UserProfile, String>((ref, userId) async {
  final useCase = ref.read(getUserProfileUseCaseByIdProvider);
  final result = await useCase(GetUserProfileParams(userId: userId));
  return result.fold(
    (failure) => throw failure,
    (profile) => profile,
  );
});
