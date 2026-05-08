import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../state/auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required SignInUseCase signIn,
    required SignUpUseCase signUp,
  })  : _signIn = signIn,
        _signUp = signUp,
        super(const AuthInitial());

  final SignInUseCase _signIn;
  final SignUpUseCase _signUp;

  Future<void> signIn({required String email, required String password}) async {
    state = const AuthLoading();
    final result = await _signIn(SignInParams(email: email, password: password));
    state = result.match(
      (failure) => AuthError(failure),
      (session) => AuthAuthenticated(session),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AuthLoading();
    final result = await _signUp(
      SignUpParams(email: email, password: password, displayName: displayName),
    );
    state = result.match(
      (failure) => AuthError(failure),
      (session) => AuthAuthenticated(session),
    );
  }

  void reset() => state = const AuthInitial();
}
