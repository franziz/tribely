import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDatasource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  final AuthRemoteDatasource _remote;
  final TokenStorage _tokenStorage;

  @override
  Future<Either<Failure, AuthSession>> signIn({
    required String email,
    required String password,
  }) async {
    return _runAuth(
      () => _remote.signIn(email: email, password: password),
    );
  }

  @override
  Future<Either<Failure, AuthSession>> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _runAuth(
      () => _remote.signUp(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _tokenStorage.clear();
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthSession?>> currentSession() async {
    try {
      final token = await _tokenStorage.readAccessToken();
      if (token == null) return const Right(null);
      // TODO: hydrate full session via /auth/me when endpoint exists.
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, AuthSession>> _runAuth(
    Future<dynamic> Function() request,
  ) async {
    try {
      final model = await request();
      final session = model.toEntity() as AuthSession;
      await _tokenStorage.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      return Right(session);
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is ServerException) {
        if (inner.statusCode == 401) {
          return Left(AuthFailure(inner.message, code: inner.code));
        }
        if (inner.statusCode == 400) {
          return Left(ValidationFailure(inner.message, code: inner.code));
        }
        return Left(
          ServerFailure(
            inner.message,
            statusCode: inner.statusCode,
            code: inner.code,
          ),
        );
      }
      if (inner is NetworkException) {
        return Left(NetworkFailure(inner.message));
      }
      return Left(UnknownFailure(e.message ?? 'Unknown error'));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
