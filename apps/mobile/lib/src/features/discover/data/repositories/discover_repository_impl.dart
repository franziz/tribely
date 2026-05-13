import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../events/domain/entities/event.dart';
import '../../domain/entities/discover_filters.dart';
import '../../domain/entities/event_page.dart';
import '../../domain/repositories/discover_repository.dart';
import '../datasources/discover_remote_datasource.dart';

class DiscoverRepositoryImpl implements DiscoverRepository {
  const DiscoverRepositoryImpl({required DiscoverRemoteDatasource remote})
    : _remote = remote;

  final DiscoverRemoteDatasource _remote;

  @override
  Future<Either<Failure, EventPage>> browseEvents(
    DiscoverFilters filters,
  ) async {
    try {
      final response = await _remote.browseEvents(filters);
      return Right(
        EventPage(
          events: response.events.map((m) => m.toEntity()).toList(),
          nextCursor: response.nextCursor,
        ),
      );
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Event>> getEventDetail(String eventId) async {
    try {
      final model = await _remote.getEventDetail(eventId);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Event>>> listMyHostedEvents() async {
    try {
      final response = await _remote.listMyHostedEvents();
      return Right(response.events.map((m) => m.toEntity()).toList());
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
        case 404:
          return NotFoundFailure(inner.message, code: inner.code);
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
