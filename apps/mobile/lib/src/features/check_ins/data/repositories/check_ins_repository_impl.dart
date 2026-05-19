import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/pending_check_in.dart';
import '../../domain/repositories/check_ins_repository.dart';
import '../datasources/check_ins_remote_datasource.dart';

class CheckInsRepositoryImpl implements CheckInsRepository {
  const CheckInsRepositoryImpl({required CheckInsRemoteDataSource remote})
    : _remote = remote;

  final CheckInsRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<PendingCheckIn>>> surfacePending() async {
    try {
      final models = await _remote.getPending();
      return Right(models.map((m) => m.toEntity()).toList(growable: false));
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> acknowledge(String checkInId) async {
    try {
      await _remote.acknowledge(checkInId);
      return const Right(unit);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> flag(
    String checkInId,
    String reportBody,
  ) async {
    try {
      await _remote.flag(checkInId, reportBody);
      return const Right(unit);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Dio → Failure mapping
  //
  // Follows the same pattern as JoinRequestRepositoryImpl: ServerException
  // carries statusCode + code from the ApiClient error interceptor;
  // NetworkException covers connectivity failures.
  // ---------------------------------------------------------------------------

  Failure _mapDioError(DioException e) {
    final inner = e.error;

    if (inner is NetworkException) {
      return NetworkFailure(inner.message);
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure('Request timed out');
    }

    if (inner is ServerException) {
      return ServerFailure(
        inner.message,
        statusCode: inner.statusCode,
        code: inner.code,
      );
    }

    return UnknownFailure(e.message ?? 'Unknown error');
  }
}
