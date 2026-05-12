import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_me_usecase.dart';
import '../../features/auth/domain/usecases/refresh_session_usecase.dart';
import '../../features/auth/domain/usecases/request_password_reset_usecase.dart';
import '../../features/auth/domain/usecases/resend_verification_usecase.dart';
import '../../features/auth/domain/usecases/reset_password_usecase.dart';
import '../../features/auth/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/domain/usecases/sign_out_usecase.dart';
import '../../features/auth/domain/usecases/sign_up_usecase.dart';
import '../../features/auth/domain/usecases/verify_email_usecase.dart';
import '../../features/events/data/datasources/event_draft_local_datasource.dart';
import '../../features/events/data/datasources/event_remote_datasource.dart';
import '../../features/events/data/repositories/event_repository_impl.dart';
import '../../features/events/domain/repositories/event_repository.dart';
import '../../features/events/domain/usecases/clear_event_draft_usecase.dart';
import '../../features/events/domain/usecases/create_event_usecase.dart';
import '../../features/events/domain/usecases/load_event_draft_usecase.dart';
import '../../features/events/domain/usecases/save_event_draft_usecase.dart';
import '../../features/discover/data/datasources/discover_remote_datasource.dart';
import '../../features/discover/data/repositories/discover_repository_impl.dart';
import '../../features/discover/domain/repositories/discover_repository.dart';
import '../../features/discover/domain/usecases/browse_events_usecase.dart';
import '../../features/discover/domain/usecases/get_event_detail_usecase.dart';
import '../../features/users/data/datasources/user_profile_remote_datasource.dart';
import '../../features/users/data/repositories/user_profile_repository_impl.dart';
import '../../features/users/domain/repositories/user_profile_repository.dart';

final GetIt sl = GetIt.instance;

Future<void> configureDependencies() async {
  // Core
  sl.registerSingleton<AppConfig>(AppConfig.dev);
  sl.registerSingleton<TokenStorage>(
    TokenStorage(const FlutterSecureStorage()),
  );
  sl.registerSingleton<ApiClient>(
    ApiClient(config: sl<AppConfig>(), tokenStorage: sl<TokenStorage>()),
  );

  // Auth — datasources
  sl.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasourceImpl(sl<ApiClient>().dio),
  );

  // Auth — repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remote: sl<AuthRemoteDatasource>(),
      tokenStorage: sl<TokenStorage>(),
    ),
  );

  // Auth — use cases
  sl.registerLazySingleton(() => SignInUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => SignUpUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => RefreshSessionUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => SignOutUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => GetMeUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => VerifyEmailUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(
    () => ResendVerificationUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton(
    () => RequestPasswordResetUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton(() => ResetPasswordUseCase(sl<AuthRepository>()));

  // Users — datasources
  sl.registerLazySingleton<UserProfileRemoteDatasource>(
    () => UserProfileRemoteDatasourceImpl(sl<ApiClient>().dio),
  );

  // Users — repositories
  sl.registerLazySingleton<UserProfileRepository>(
    () => UserProfileRepositoryImpl(remote: sl<UserProfileRemoteDatasource>()),
  );

  // Users — use cases are constructed inline in users_providers.dart via
  // Riverpod ref.read() so they can resolve Riverpod-backed ports (e.g.
  // SessionReader). No use-case registrations here.

  // Events — SharedPreferences (async init, resolved once at boot)
  final prefs = await SharedPreferences.getInstance();

  // Events — datasources
  sl.registerLazySingleton<EventRemoteDatasource>(
    () => EventRemoteDatasourceImpl(sl<ApiClient>().dio),
  );
  sl.registerLazySingleton<EventDraftLocalDatasource>(
    () => EventDraftLocalDatasourceImpl(prefs),
  );

  // Events — repositories
  sl.registerLazySingleton<EventRepository>(
    () => EventRepositoryImpl(
      remote: sl<EventRemoteDatasource>(),
      local: sl<EventDraftLocalDatasource>(),
    ),
  );

  // Events — use cases
  sl.registerLazySingleton(() => CreateEventUseCase(sl<EventRepository>()));
  sl.registerLazySingleton(() => SaveEventDraftUseCase(sl<EventRepository>()));
  sl.registerLazySingleton(() => LoadEventDraftUseCase(sl<EventRepository>()));
  sl.registerLazySingleton(() => ClearEventDraftUseCase(sl<EventRepository>()));

  // Discover — datasources
  sl.registerLazySingleton<DiscoverRemoteDatasource>(
    () => DiscoverRemoteDatasourceImpl(sl<ApiClient>().dio),
  );

  // Discover — repositories
  sl.registerLazySingleton<DiscoverRepository>(
    () => DiscoverRepositoryImpl(remote: sl<DiscoverRemoteDatasource>()),
  );

  // Discover — use cases
  sl.registerLazySingleton(
    () => BrowseEventsUseCase(sl<DiscoverRepository>()),
  );
  sl.registerLazySingleton(
    () => GetEventDetailUseCase(sl<DiscoverRepository>()),
  );
}
