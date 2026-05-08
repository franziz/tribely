import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../controllers/auth_controller.dart';
import '../state/auth_state.dart';

final signInUseCaseProvider = Provider<SignInUseCase>((_) => sl<SignInUseCase>());
final signUpUseCaseProvider = Provider<SignUpUseCase>((_) => sl<SignUpUseCase>());

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    signIn: ref.watch(signInUseCaseProvider),
    signUp: ref.watch(signUpUseCaseProvider),
  );
});
