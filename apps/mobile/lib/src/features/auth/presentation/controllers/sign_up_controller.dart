import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

class SignUpController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormIdle();

  Future<void> submit({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AuthFormSubmitting();
    final useCase = ref.read(signUpUseCaseProvider);
    final params = SignUpParams(
      email: email,
      password: password,
      displayName: displayName,
    );
    final result = await useCase(params);
    state = result.match(
      (failure) {
        // 409 (email already exists) — special-case so the page can show a
        // gentle recovery banner with "Sign in instead →".
        if (failure is ValidationFailure &&
            failure.message.toLowerCase().contains('already')) {
          return AuthFormError(
            failure: failure,
            bannerMessage: 'An account with that email already exists.',
            suggestSignInWithEmail: email,
          );
        }
        return AuthFormError(
          failure: failure,
          bannerMessage: _bannerFor(failure),
        );
      },
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
    NetworkFailure() => "Couldn't reach Tribely. Check your connection.",
    ServerFailure(:final statusCode) when statusCode == 429 =>
      'Too many attempts. Try again in a minute.',
    ServerFailure() => "Something's off on our end. Give it a moment.",
    AuthFailure() => failure.message,
    EmailNotVerifiedFailure() => failure.message,
    ValidationFailure() => failure.message,
    NotFoundFailure() => failure.message,
    CapacityFullFailure() => failure.message,
    ConflictFailure() => failure.message,
    FirstEventMustBePublicFailure() => failure.message,
    UnknownFailure() => failure.message,
  };
}
