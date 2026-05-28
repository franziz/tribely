import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/support_ticket_draft.dart';
import '../../domain/repositories/support_repository.dart';
import '../datasources/support_remote_data_source.dart';
import '../models/support_ticket_request_model.dart';

class SupportRepositoryImpl implements SupportRepository {
  const SupportRepositoryImpl({required SupportRemoteDataSource remote})
    : _remote = remote;

  final SupportRemoteDataSource _remote;

  @override
  Future<Either<Failure, SubmitResult>> submitTicket(
    SupportTicketDraft draft,
  ) async {
    try {
      final model = await _remote.submitTicket(
        SupportTicketRequestModel.fromDraft(draft),
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

        case 422:
          // 422 with subcode `support.rateLimited` → distinct failure type
          // so the UI can show rate-limit–specific copy.
          if (code == 'support.rateLimited') {
            return RateLimitedFailure(message, code: code);
          }
          return ValidationFailure(message, code: code);

        case 400:
          return ValidationFailure(message, code: code);

        default:
          return ServerFailure(message, statusCode: statusCode, code: code);
      }
    }

    return UnknownFailure(e.message ?? 'Unknown error');
  }
}
