import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

class SignInController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormIdle();

  Future<void> submit({required String email, required String password}) async {
    state = const AuthFormSubmitting();
    final useCase = ref.read(signInUseCaseProvider);
    final params = SignInParams(email: email, password: password);
    final result = await useCase(params);
    state = result.match(
      (failure) =>
          AuthFormError(failure: failure, bannerMessage: _bannerFor(failure)),
      (session) {
        ref.read(sessionControllerProvider.notifier).setAuthenticated(session);
        return const AuthFormSuccess();
      },
    );
  }

  void reset() => state = const AuthFormIdle();
}

String _bannerFor(Failure failure) {
  return switch (failure) {
    AuthFailure() =>
      'That email and password didn\'t match. Try again, or reset your password.',
    NetworkFailure() => "Couldn't reach Tribely. Check your connection.",
    ServerFailure(:final statusCode) when statusCode == 429 =>
      'Too many attempts. Try again in a minute.',
    ServerFailure() => "Something's off on our end. Give it a moment.",
    EmailNotVerifiedFailure() => failure.message,
    PhoneNotVerifiedFailure() => failure.message,
    ValidationFailure() => failure.message,
    NotFoundFailure() => failure.message,
    CapacityFullFailure() => failure.message,
    ConflictFailure() => failure.message,
    FirstEventMustBePublicFailure() => failure.message,
    UnknownFailure() => failure.message,
  };
}
