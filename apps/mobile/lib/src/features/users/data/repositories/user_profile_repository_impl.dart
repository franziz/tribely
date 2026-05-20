import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/ports/user_profile_port.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/user_profile_remote_datasource.dart';
import '../models/update_profile_params_model.dart';

class UserProfileRepositoryImpl
    implements UserProfileRepository, UserProfilePort {
  UserProfileRepositoryImpl({required UserProfileRemoteDatasource remote})
    : _remote = remote;

  final UserProfileRemoteDatasource _remote;

  @override
  Future<Either<Failure, UserProfile>> getUserProfile(String id) =>
      _fetchProfile(id);

  @override
  Future<Either<Failure, UserProfile>> updateMyProfile(
    UpdateProfileParams params,
  ) async {
    try {
      final model = await _remote.updateMyProfile(
        UpdateProfileParamsModel.fromDomain(params),
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, UserProfile>> _fetchProfile(String id) async {
    try {
      final model = await _remote.getUserProfile(id);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Failure _mapDioError(DioException e) {
    final inner = e.error;
    if (inner is ServerException) {
      return switch (inner.statusCode) {
        401 => AuthFailure(inner.message, code: inner.code),
        404 => ServerFailure(inner.message, statusCode: 404, code: inner.code),
        422 => ValidationFailure(inner.message, code: inner.code),
        _ => ServerFailure(
          inner.message,
          statusCode: inner.statusCode,
          code: inner.code,
        ),
      };
    }
    if (inner is NetworkException) return NetworkFailure(inner.message);
    return UnknownFailure(e.message ?? 'Unknown error');
  }
}
