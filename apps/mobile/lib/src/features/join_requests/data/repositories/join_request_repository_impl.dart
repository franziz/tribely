import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/join_request.dart';
import '../../domain/entities/join_request_with_event.dart';
import '../../domain/entities/join_request_with_requester.dart';
import '../../domain/repositories/join_request_repository.dart';
import '../datasources/join_request_remote_datasource.dart';

class JoinRequestRepositoryImpl implements JoinRequestRepository {
  const JoinRequestRepositoryImpl({required JoinRequestRemoteDatasource remote})
    : _remote = remote;

  final JoinRequestRemoteDatasource _remote;

  @override
  Future<Either<Failure, JoinRequest>> requestToJoin({
    required String eventId,
  }) async {
    try {
      final model = await _remote.requestToJoin(eventId: eventId);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, JoinRequest>> approve({
    required String joinRequestId,
  }) async {
    try {
      final model = await _remote.approve(joinRequestId: joinRequestId);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, JoinRequest>> decline({
    required String joinRequestId,
    String? reason,
  }) async {
    try {
      final model = await _remote.decline(
        joinRequestId: joinRequestId,
        reason: reason,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> withdraw({
    required String joinRequestId,
  }) async {
    try {
      await _remote.withdraw(joinRequestId: joinRequestId);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<JoinRequestWithRequester>>> listPendingForEvent({
    required String eventId,
  }) async {
    try {
      final models = await _remote.listPendingForEvent(eventId: eventId);
      return Right(models.map((m) => m.toEntity()).toList(growable: false));
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<JoinRequestWithRequester>>> listApprovedForEvent({
    required String eventId,
  }) async {
    try {
      final models = await _remote.listApprovedForEvent(eventId: eventId);
      return Right(models.map((m) => m.toEntity()).toList(growable: false));
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<JoinRequestWithEvent>>> listMyJoinRequests({
    String? eventId,
  }) async {
    try {
      final models = await _remote.listMyJoinRequests(eventId: eventId);
      return Right(models.map((m) => m.toEntity()).toList(growable: false));
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Dio → Failure mapping
  //
  // The _ErrorInterceptor in ApiClient wraps the response in ServerException
  // carrying the top-level error.code (e.g. 'CONFLICT'). The subcode lives in
  // error.details.subcode on the wire; we read it from e.response?.data because
  // ServerException does not carry details. Network/timeout errors arrive as
  // DioExceptions whose inner error is a NetworkException.
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
        case 403:
          if (code == 'EMAIL_NOT_VERIFIED') {
            return EmailNotVerifiedFailure(message, code: code);
          }
          return ServerFailure(message, statusCode: 403, code: code);

        case 409:
          // subcode is in error.details.subcode on the wire — read from response data.
          final subcode = _extractSubcode(e);
          if (subcode == 'CAPACITY_FULL') {
            return CapacityFullFailure(message, code: code);
          }
          if (subcode == 'ALREADY_APPROVED' ||
              subcode == 'ALREADY_REJECTED' ||
              subcode == 'ALREADY_CANCELLED') {
            return ConflictFailure(message, subcode: subcode, code: code);
          }
          return ServerFailure(message, statusCode: 409, code: code);

        case 422:
          // PAST_EVENT / IS_HOST surface as 422 with a code in the body.
          return ValidationFailure(message, code: code);

        default:
          return ServerFailure(message, statusCode: statusCode, code: code);
      }
    }

    return UnknownFailure(e.message ?? 'Unknown error');
  }

  /// Extracts `error.details.subcode` from the raw Dio response body.
  /// Returns an empty string when the path is absent so callers can compare
  /// safely without null checks.
  String _extractSubcode(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final error = data['error'];
        if (error is Map<String, dynamic>) {
          final details = error['details'];
          if (details is Map<String, dynamic>) {
            return (details['subcode'] as String?) ?? '';
          }
        }
      }
    } catch (_) {
      // Defensive: malformed response shape — fall through to empty string.
    }
    return '';
  }
}
