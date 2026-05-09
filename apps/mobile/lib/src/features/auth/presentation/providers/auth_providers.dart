import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/get_me_usecase.dart';
import '../../domain/usecases/refresh_session_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../controllers/session_controller.dart';
import '../controllers/sign_in_controller.dart';
import '../controllers/sign_up_controller.dart';
import '../state/auth_state.dart';

// --- Use cases (resolved via get_it) ---

final signInUseCaseProvider = Provider<SignInUseCase>(
  (_) => sl<SignInUseCase>(),
);
final signUpUseCaseProvider = Provider<SignUpUseCase>(
  (_) => sl<SignUpUseCase>(),
);
final refreshSessionUseCaseProvider = Provider<RefreshSessionUseCase>(
  (_) => sl<RefreshSessionUseCase>(),
);
final signOutUseCaseProvider = Provider<SignOutUseCase>(
  (_) => sl<SignOutUseCase>(),
);
final getMeUseCaseProvider = Provider<GetMeUseCase>((_) => sl<GetMeUseCase>());

// --- Controllers (Riverpod 3.x Notifier API) ---

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

final signInControllerProvider =
    NotifierProvider<SignInController, AuthFormState>(SignInController.new);

final signUpControllerProvider =
    NotifierProvider<SignUpController, AuthFormState>(SignUpController.new);
