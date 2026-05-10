import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_response_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDatasource remote,
    required TokenStorage tokenStorage,
  }) : _remote = remote,
       _tokenStorage = tokenStorage;

  final AuthRemoteDatasource _remote;
  final TokenStorage _tokenStorage;

  @override
  Future<Either<Failure, AuthSession>> signIn({
    required String email,
    required String password,
  }) => _runAuth(() => _remote.signIn(email: email, password: password));

  @override
  Future<Either<Failure, AuthSession>> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => _runAuth(
    () => _remote.signUp(
      email: email,
      password: password,
      displayName: displayName,
    ),
  );

  @override
  Future<Either<Failure, AuthSession>> refresh() async {
    final stored = await _tokenStorage.readRefreshToken();
    if (stored == null) {
      return const Left(AuthFailure('No stored refresh token'));
    }
    return _runAuth(() => _remote.refresh(refreshToken: stored));
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    final refresh = await _tokenStorage.readRefreshToken();
    try {
      if (refresh != null) {
        await _remote.signOut(refreshToken: refresh);
      }
      await _tokenStorage.clear();
      return const Right(null);
    } on DioException catch (e) {
      // Even if the API call fails, we clear local tokens so the user
      // is signed out on this device. The backend will eventually GC the
      // server-side row.
      await _tokenStorage.clear();
      return Left(_mapDioError(e));
    } catch (e) {
      await _tokenStorage.clear();
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOutAll() async {
    try {
      await _remote.signOutAll();
      await _tokenStorage.clear();
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> me() async {
    try {
      final model = await _remote.me();
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> verifyEmail({required String code}) async {
    try {
      final model = await _remote.verifyEmail(code: code);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resendVerification() async {
    try {
      await _remote.resendVerification();
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> requestPasswordReset({
    required String email,
  }) async {
    try {
      await _remote.requestPasswordReset(email: email);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _remote.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  /// Centralized auth-flow error mapping. Persists tokens on success.
  /// Strongly typed — the duck-typed `(model as dynamic).toEntity()` of the
  /// previous version silently broke when the API response shape changed.
  Future<Either<Failure, AuthSession>> _runAuth(
    Future<AuthResponseModel> Function() request,
  ) async {
    try {
      final model = await request();
      final session = model.toEntity();
      await _tokenStorage.saveTokens(
        accessToken: session.accessToken,
        accessExpiresAt: session.accessTokenExpiresAt,
        refreshToken: session.refreshToken,
        refreshExpiresAt: session.refreshTokenExpiresAt,
      );
      return Right(session);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Failure _mapDioError(DioException e) {
    final inner = e.error;
    if (inner is ServerException) {
      switch (inner.statusCode) {
        case 401:
          return AuthFailure(inner.message, code: inner.code);
        case 403:
          if (inner.code == 'EMAIL_NOT_VERIFIED') {
            return EmailNotVerifiedFailure(inner.message, code: inner.code);
          }
          return ServerFailure(
            inner.message,
            statusCode: 403,
            code: inner.code,
          );
        case 409:
          return ValidationFailure(inner.message, code: inner.code);
        case 429:
          return ServerFailure(
            inner.message,
            statusCode: 429,
            code: inner.code,
          );
        case 400:
          return ValidationFailure(inner.message, code: inner.code);
        default:
          return ServerFailure(
            inner.message,
            statusCode: inner.statusCode,
            code: inner.code,
          );
      }
    }
    if (inner is NetworkException) {
      return NetworkFailure(inner.message);
    }
    return UnknownFailure(e.message ?? 'Unknown error');
  }
}
