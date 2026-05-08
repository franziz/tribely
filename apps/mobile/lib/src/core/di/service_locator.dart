import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/domain/usecases/sign_up_usecase.dart';

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
}
