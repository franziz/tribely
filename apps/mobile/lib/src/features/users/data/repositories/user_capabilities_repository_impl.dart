import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_capabilities.dart';
import '../../domain/repositories/user_capabilities_repository.dart';
import '../datasources/user_capabilities_remote_datasource.dart';

class UserCapabilitiesRepositoryImpl implements UserCapabilitiesRepository {
  UserCapabilitiesRepositoryImpl({
    required UserCapabilitiesRemoteDatasource remote,
  }) : _remote = remote;

  final UserCapabilitiesRemoteDatasource _remote;

  @override
  Future<Either<Failure, UserCapabilities>> getMyCapabilities() async {
    try {
      final data = await _remote.getMyCapabilities();
      final canPostPrivateVenue = data['canPostPrivateVenue'] as bool? ?? false;
      return Right(UserCapabilities(canPostPrivateVenue: canPostPrivateVenue));
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
