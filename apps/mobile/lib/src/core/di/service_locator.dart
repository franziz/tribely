import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/datasources/phone_verification_remote_datasource.dart';
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
import '../../features/auth/domain/usecases/start_phone_verification_usecase.dart';
import '../../features/auth/domain/usecases/verify_email_usecase.dart';
import '../../features/auth/domain/usecases/verify_phone_usecase.dart';
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
import '../../features/discover/domain/usecases/list_my_hosted_events_usecase.dart';
import '../../features/join_requests/data/datasources/join_request_remote_datasource.dart';
import '../../features/join_requests/data/repositories/join_request_repository_impl.dart';
import '../../features/join_requests/domain/repositories/join_request_repository.dart';
import '../../features/join_requests/domain/usecases/approve_join_request_usecase.dart';
import '../../features/join_requests/domain/usecases/decline_join_request_usecase.dart';
import '../../features/join_requests/domain/usecases/list_approved_for_event_usecase.dart';
import '../../features/join_requests/domain/usecases/list_my_join_requests_usecase.dart';
import '../../features/join_requests/domain/usecases/list_pending_for_event_usecase.dart';
import '../../features/join_requests/domain/usecases/request_to_join_event_usecase.dart';
import '../../features/join_requests/domain/usecases/withdraw_join_request_usecase.dart';
import '../../features/users/data/datasources/user_capabilities_remote_datasource.dart';
import '../../features/users/data/datasources/user_profile_remote_datasource.dart';
import '../../features/users/data/repositories/user_capabilities_repository_impl.dart';
import '../../features/users/data/repositories/user_profile_repository_impl.dart';
import '../../features/users/domain/repositories/user_capabilities_repository.dart';
import '../../features/users/domain/repositories/user_profile_repository.dart';
import '../../features/check_ins/data/datasources/check_ins_remote_datasource.dart';
import '../../features/check_ins/data/repositories/check_ins_repository_impl.dart';
import '../../features/check_ins/domain/repositories/check_ins_repository.dart';
import '../../features/check_ins/domain/usecases/acknowledge_check_in_usecase.dart';
import '../../features/check_ins/domain/usecases/flag_check_in_usecase.dart';
import '../../features/check_ins/domain/usecases/surface_pending_check_ins_usecase.dart';
import '../../features/users/domain/usecases/get_user_profile_usecase.dart';
import '../../features/account/data/datasources/account_remote_datasource.dart';
import '../../features/account/data/repositories/account_repository_impl.dart';
import '../../features/account/domain/repositories/account_repository.dart';
import '../../features/account/domain/usecases/delete_account_usecase.dart';
import '../storage/intro_flag_storage.dart';
import '../../features/reviews/data/datasources/review_remote_datasource.dart';
import '../../features/reviews/data/repositories/review_repository_impl.dart';
import '../../features/reviews/domain/repositories/review_repository.dart';
import '../../features/reviews/domain/usecases/submit_review_usecase.dart';
import '../../features/reviews/domain/usecases/edit_review_usecase.dart';
import '../../features/reviews/domain/usecases/list_reviews_for_user_usecase.dart';
import '../../features/reviews/domain/usecases/list_reviews_written_by_me_usecase.dart';

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
  sl.registerLazySingleton<PhoneVerificationRemoteDatasource>(
    () => PhoneVerificationRemoteDatasourceImpl(sl<ApiClient>().dio),
  );

  // Auth — repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remote: sl<AuthRemoteDatasource>(),
      tokenStorage: sl<TokenStorage>(),
      phoneRemote: sl<PhoneVerificationRemoteDatasource>(),
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
  sl.registerLazySingleton(
    () => StartPhoneVerificationUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton(() => VerifyPhoneUseCase(sl<AuthRepository>()));

  // Users — datasources
  sl.registerLazySingleton<UserProfileRemoteDatasource>(
    () => UserProfileRemoteDatasourceImpl(sl<ApiClient>().dio),
  );
  sl.registerLazySingleton<UserCapabilitiesRemoteDatasource>(
    () => UserCapabilitiesRemoteDatasourceImpl(sl<ApiClient>().dio),
  );

  // Users — repositories
  sl.registerLazySingleton<UserProfileRepository>(
    () => UserProfileRepositoryImpl(remote: sl<UserProfileRemoteDatasource>()),
  );
  sl.registerLazySingleton<UserCapabilitiesRepository>(
    () => UserCapabilitiesRepositoryImpl(
      remote: sl<UserCapabilitiesRemoteDatasource>(),
    ),
  );

  // Users — use cases
  // GetUserProfileUseCase is registered here so core/providers/ can bridge it
  // to Riverpod for cross-feature profile lookups (join_requests, discover).
  // Other users use cases that need Riverpod-backed ports (SessionReader) are
  // still constructed inline in users_providers.dart.
  sl.registerLazySingleton<GetUserProfileUseCase>(
    () => GetUserProfileUseCase(sl<UserProfileRepository>()),
  );

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
  sl.registerLazySingleton(() => BrowseEventsUseCase(sl<DiscoverRepository>()));
  sl.registerLazySingleton(
    () => GetEventDetailUseCase(sl<DiscoverRepository>()),
  );
  sl.registerLazySingleton(
    () => ListMyHostedEventsUseCase(sl<DiscoverRepository>()),
  );

  // CheckIns — datasources
  sl.registerLazySingleton<CheckInsRemoteDataSource>(
    () => CheckInsRemoteDataSourceImpl(sl<ApiClient>().dio),
  );

  // CheckIns — repositories
  sl.registerLazySingleton<CheckInsRepository>(
    () => CheckInsRepositoryImpl(remote: sl<CheckInsRemoteDataSource>()),
  );

  // CheckIns — use cases
  sl.registerLazySingleton(
    () => SurfacePendingCheckInsUseCase(sl<CheckInsRepository>()),
  );
  sl.registerLazySingleton(
    () => AcknowledgeCheckInUseCase(sl<CheckInsRepository>()),
  );
  sl.registerLazySingleton(() => FlagCheckInUseCase(sl<CheckInsRepository>()));

  // Core — IntroFlagStorage (reuses SharedPreferences instance from Events)
  sl.registerLazySingleton(() => IntroFlagStorage(prefs));

  // JoinRequests — datasources
  sl.registerLazySingleton<JoinRequestRemoteDatasource>(
    () => JoinRequestRemoteDatasourceImpl(sl<ApiClient>().dio),
  );

  // JoinRequests — repositories
  sl.registerLazySingleton<JoinRequestRepository>(
    () => JoinRequestRepositoryImpl(remote: sl<JoinRequestRemoteDatasource>()),
  );

  // JoinRequests — use cases
  sl.registerLazySingleton(
    () => RequestToJoinEventUseCase(sl<JoinRequestRepository>()),
  );
  sl.registerLazySingleton(
    () => ApproveJoinRequestUseCase(sl<JoinRequestRepository>()),
  );
  sl.registerLazySingleton(
    () => DeclineJoinRequestUseCase(sl<JoinRequestRepository>()),
  );
  sl.registerLazySingleton(
    () => WithdrawJoinRequestUseCase(sl<JoinRequestRepository>()),
  );
  sl.registerLazySingleton(
    () => ListPendingForEventUseCase(sl<JoinRequestRepository>()),
  );
  sl.registerLazySingleton(
    () => ListApprovedForEventUseCase(sl<JoinRequestRepository>()),
  );
  sl.registerLazySingleton(
    () => ListMyJoinRequestsUseCase(sl<JoinRequestRepository>()),
  );

  // Account — datasources
  sl.registerLazySingleton<AccountRemoteDatasource>(
    () => AccountRemoteDatasourceImpl(sl<ApiClient>().dio),
  );

  // Account — repositories
  sl.registerLazySingleton<AccountRepository>(
    () => AccountRepositoryImpl(remote: sl<AccountRemoteDatasource>()),
  );

  // Account — use cases
  sl.registerLazySingleton(() => DeleteAccountUseCase(sl<AccountRepository>()));

  // Reviews — datasources
  sl.registerLazySingleton<ReviewRemoteDatasource>(
    () => ReviewRemoteDatasourceImpl(sl<ApiClient>().dio),
  );

  // Reviews — repositories
  sl.registerLazySingleton<ReviewRepository>(
    () => ReviewRepositoryImpl(remote: sl<ReviewRemoteDatasource>()),
  );

  // Reviews — use cases
  sl.registerLazySingleton(() => SubmitReviewUseCase(sl<ReviewRepository>()));
  sl.registerLazySingleton(() => EditReviewUseCase(sl<ReviewRepository>()));
  sl.registerLazySingleton(
    () => ListReviewsForUserUseCase(sl<ReviewRepository>()),
  );
  sl.registerLazySingleton(
    () => ListReviewsWrittenByMeUseCase(sl<ReviewRepository>()),
  );
}
