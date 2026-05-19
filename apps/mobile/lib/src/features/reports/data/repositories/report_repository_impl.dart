import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/report.dart';
import '../../domain/entities/report_reason.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_datasource.dart';

class ReportRepositoryImpl implements ReportRepository {
  const ReportRepositoryImpl({required ReportRemoteDatasource remote})
    : _remote = remote;

  final ReportRemoteDatasource _remote;

  @override
  Future<Either<Failure, Report>> fileReport({
    required String targetType,
    required String targetId,
    required ReportReason reason,
    String? comment,
  }) async {
    try {
      final model = await _remote.fileReport(
        targetType: targetType,
        targetId: targetId,
        reason: reason.wireValue,
        comment: comment,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Dio → Failure mapping
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
      final statusCode = inner.statusCode;
      final code = inner.code;
      final message = inner.message;

      switch (statusCode) {
        case 401:
          return AuthFailure(message, code: code);

        case 403:
          if (code == 'EMAIL_NOT_VERIFIED') {
            return EmailNotVerifiedFailure(message, code: code);
          }
          return ServerFailure(message, statusCode: 403, code: code);

        case 404:
          // The report target (e.g. review) no longer exists.
          return TargetNotFoundFailure(message, code: code);

        case 422:
          // The server does not yet support reporting this target type.
          return TargetTypeNotImplementedFailure(message, code: code);

        case 400:
          return ValidationFailure(message, code: code);

        default:
          return ServerFailure(message, statusCode: statusCode, code: code);
      }
    }

    return UnknownFailure(e.message ?? 'Unknown error');
  }
}
