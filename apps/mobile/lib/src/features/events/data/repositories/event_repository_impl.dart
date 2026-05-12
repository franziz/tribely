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

class EventRepositoryImpl implements EventRepository {
  const EventRepositoryImpl({
    required EventRemoteDatasource remote,
    required EventDraftLocalDatasource local,
  })  : _remote = remote,
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
          return ServerFailure(
            inner.message,
            statusCode: 403,
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
}
