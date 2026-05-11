import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../providers/users_providers.dart';
import '../state/user_profile_state.dart';

class MyProfileController extends Notifier<UserProfileState> {
  @override
  UserProfileState build() {
    Future(_load);
    return const UserProfileLoading();
  }

  Future<void> _load() async {
    final useCase = ref.read(getMyProfileUseCaseProvider);
    final params = const NoParams();
    final result = await useCase(params);
    if (!ref.mounted) return;
    state = result.match(
      (failure) =>
          UserProfileError(failure: failure, message: _messageFor(failure)),
      UserProfileLoaded.new,
    );
  }

  Future<void> retry() async {
    state = const UserProfileLoading();
    await _load();
  }
}

String _messageFor(Failure failure) => switch (failure) {
  NetworkFailure() => "Couldn't reach Tribely. Check your connection.",
  ServerFailure(:final statusCode) when statusCode == 404 =>
    'Profile not found.',
  ServerFailure() => 'Something went wrong. Try again.',
  AuthFailure() => 'Please sign in to view this profile.',
  _ => failure.message,
};
