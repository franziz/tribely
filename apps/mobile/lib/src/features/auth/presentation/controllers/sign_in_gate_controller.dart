import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../providers/auth_providers.dart';
import '../state/sign_in_gate_state.dart';
import '../state/sign_in_intent.dart';

/// Controller for [SignInGateSheet].
///
/// Family-parameterised on [SignInIntent] so each call-site gets its own
/// isolated controller lifecycle. The intent is stored at construction time
/// and drives only the context-aware headline copy in the sheet — auth logic
/// is identical across all intent variants.
///
/// Lifecycle: [NotifierProvider.autoDispose.family] — disposed automatically
/// when the sheet is popped, preventing state leaks across separate sign-in
/// gate appearances.
class SignInGateController extends Notifier<SignInGateState> {
  SignInGateController(this.intent);

  /// The intent that triggered the gate. Used by the sheet for copy only.
  final SignInIntent intent;

  @override
  SignInGateState build() => const SignInGateIdle();

  Future<void> submit({required String email, required String password}) async {
    state = const SignInGateSubmitting();

    final useCase = ref.read(signInUseCaseProvider);
    final params = SignInParams(email: email, password: password);
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.match(
      (failure) =>
          SignInGateError(failure: failure, message: _bannerFor(failure)),
      (session) {
        ref.read(sessionControllerProvider.notifier).setAuthenticated(session);
        return const SignInGateSuccess();
      },
    );
  }

  void reset() => state = const SignInGateIdle();
}

/// Provider — autoDispose + family on [SignInIntent].
///
/// Calling code:
/// ```dart
/// final controller = ref.read(
///   signInGateControllerProvider(intent).notifier,
/// );
/// ```
final signInGateControllerProvider = NotifierProvider.autoDispose
    .family<SignInGateController, SignInGateState, SignInIntent>(
      SignInGateController.new,
    );

String _bannerFor(Failure failure) {
  return switch (failure) {
    AuthFailure() => 'Incorrect email or password. Please try again.',
    NetworkFailure() => 'Something went wrong. Please try again.',
    ServerFailure(:final statusCode) when statusCode == 401 =>
      'Incorrect email or password. Please try again.',
    ServerFailure() => 'Something went wrong. Please try again.',
    _ => 'Something went wrong. Please try again.',
  };
}
