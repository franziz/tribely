import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_draft.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/event_draft_local_datasource.dart';
import '../datasources/event_remote_datasource.dart';
import '../models/create_event_params_model.dart';
import '../models/event_draft_model.dart';

// ---------------------------------------------------------------------------
// Subcode constants
// ---------------------------------------------------------------------------

/// Value of `error.details.subcode` returned by the server when a
/// 422 UNPROCESSABLE error is due to the first-event-must-be-public policy.
const _kFirstEventMustBePublic = 'FIRST_EVENT_MUST_BE_PUBLIC';

/// Value of `error.code` returned by the server when an attempt is made to
/// cancel an event that is already cancelled.
const _kEventCancelled = 'EVENT_CANCELLED';

class EventRepositoryImpl implements EventRepository {
  const EventRepositoryImpl({
    required EventRemoteDatasource remote,
    required EventDraftLocalDatasource local,
  }) : _remote = remote,
       _local = local;

  final EventRemoteDatasource _remote;
  final EventDraftLocalDatasource _local;

  // ---------------------------------------------------------------------------
  // Remote methods
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, Event>> createEvent(CreateEventParams params) async {
    try {
      final model = await _remote.createEvent(
        CreateEventParamsModel.fromDomain(params),
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelEvent(String eventId) async {
    try {
      await _remote.cancelEvent(eventId);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Local draft methods
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, EventDraft?>> loadDraft() async {
    try {
      final model = await _local.load();
      return Right(model?.toEntity());
    } on CacheException catch (e) {
      return Left(UnknownFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveDraft(EventDraft draft) async {
    try {
      await _local.save(EventDraftModel.fromEntity(draft));
      return const Right(null);
    } on CacheException catch (e) {
      return Left(UnknownFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearDraft() async {
    try {
      await _local.clear();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(UnknownFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Dio → Failure mapping (mirrors auth_repository_impl.dart exactly)
  // ---------------------------------------------------------------------------

  Failure _mapDioError(DioException e) {
    final inner = e.error;
    if (inner is ServerException) {
      switch (inner.statusCode) {
        case 400:
          return ValidationFailure(inner.message, code: inner.code);
        case 401:
          return AuthFailure(inner.message, code: inner.code);
        case 403:
          if (inner.code == 'EMAIL_NOT_VERIFIED') {
            return EmailNotVerifiedFailure(inner.message, code: inner.code);
          }
          if (inner.code == 'PHONE_NOT_VERIFIED') {
            return PhoneNotVerifiedFailure(inner.message, code: inner.code);
          }
          return ServerFailure(
            inner.message,
            statusCode: 403,
            code: inner.code,
          );
        case 422:
          // TRI-33: 422 UNPROCESSABLE with subcode FIRST_EVENT_MUST_BE_PUBLIC
          // means the user's first event must use a public venue category.
          // Read details from the raw response because the _ErrorInterceptor
          // only extracts top-level `error.code`, not `error.details.subcode`.
          final subcode = _extractSubcode(e);
          if (subcode == _kFirstEventMustBePublic) {
            final reason = _extractReason(e) ?? 'category_not_public';
            return FirstEventMustBePublicFailure(reason: reason);
          }
          return ServerFailure(
            inner.message,
            statusCode: 422,
            code: inner.code,
          );
        case 409:
          // EVENT_CANCELLED: the event is already cancelled. Map to
          // ConflictFailure with the subcode so the UI can show specific copy.
          if (inner.code == _kEventCancelled) {
            return ConflictFailure(
              inner.message,
              subcode: _kEventCancelled,
              code: inner.code,
            );
          }
          return ConflictFailure(
            inner.message,
            subcode: inner.code ?? 'CONFLICT',
            code: inner.code,
          );
        case 429:
          return ServerFailure(
            inner.message,
            statusCode: 429,
            code: inner.code,
          );
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

  /// Extracts `error.details.subcode` from the raw response body.
  /// Returns null when the path is absent or the response has no body.
  static String? _extractSubcode(DioException e) {
    final data = e.response?.data;
    if (data is! Map<String, dynamic>) return null;
    final errorMap = data['error'];
    if (errorMap is! Map<String, dynamic>) return null;
    final details = errorMap['details'];
    if (details is! Map<String, dynamic>) return null;
    return details['subcode'] as String?;
  }

  /// Extracts `error.details.reason` from the raw response body.
  /// Returns null when the path is absent.
  static String? _extractReason(DioException e) {
    final data = e.response?.data;
    if (data is! Map<String, dynamic>) return null;
    final errorMap = data['error'];
    if (errorMap is! Map<String, dynamic>) return null;
    final details = errorMap['details'];
    if (details is! Map<String, dynamic>) return null;
    return details['reason'] as String?;
  }
}
