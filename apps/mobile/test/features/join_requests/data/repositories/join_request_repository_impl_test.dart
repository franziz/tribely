import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/exceptions.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/join_requests/data/datasources/join_request_remote_datasource.dart';
import 'package:tribely/src/features/join_requests/data/repositories/join_request_repository_impl.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockJoinRequestRemoteDatasource extends Mock
    implements JoinRequestRemoteDatasource {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DioException _serverDioException({
  required int statusCode,
  required String code,
  String message = 'Error',
  String? subcode,
}) {
  final data = <String, dynamic>{
    'error': <String, dynamic>{
      'code': code,
      'message': message,
      if (subcode != null) 'details': <String, dynamic>{'subcode': subcode},
    },
  };
  return DioException(
    requestOptions: RequestOptions(path: '/test'),
    error: ServerException(message, statusCode: statusCode, code: code),
    response: Response(
      requestOptions: RequestOptions(path: '/test'),
      statusCode: statusCode,
      data: data,
    ),
  );
}

DioException _networkDioException() => DioException(
  requestOptions: RequestOptions(path: '/test'),
  error: const NetworkException('Connection refused'),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockJoinRequestRemoteDatasource remote;
  late JoinRequestRepositoryImpl repo;

  setUp(() {
    remote = MockJoinRequestRemoteDatasource();
    repo = JoinRequestRepositoryImpl(remote: remote);
  });

  group('removeAttendee', () {
    const eventId = 'evt-1';
    const joinRequestId = 'jr-1';
    const reason = 'No-show at the venue';

    test('returns Right(unit) on success', () async {
      when(
        () => remote.removeAttendee(
          eventId: eventId,
          joinRequestId: joinRequestId,
          reason: reason,
        ),
      ).thenAnswer((_) async {});

      final result = await repo.removeAttendee(
        eventId: eventId,
        joinRequestId: joinRequestId,
        reason: reason,
      );

      expect(result, const Right<Failure, Unit>(unit));
    });

    test('returns NetworkFailure on network error', () async {
      when(
        () => remote.removeAttendee(
          eventId: any(named: 'eventId'),
          joinRequestId: any(named: 'joinRequestId'),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(_networkDioException());

      final result = await repo.removeAttendee(
        eventId: eventId,
        joinRequestId: joinRequestId,
        reason: reason,
      );

      expect(result.isLeft(), isTrue);
      final failure = result.swap().getOrElse((_) => const UnknownFailure(''));
      expect(failure, isA<NetworkFailure>());
    });

    test(
      '403 + subcode REMOVED_BY_HOST_REREQUEST_BLOCKED returns ServerFailure '
      'with subcode as code',
      () async {
        when(
          () => remote.removeAttendee(
            eventId: any(named: 'eventId'),
            joinRequestId: any(named: 'joinRequestId'),
            reason: any(named: 'reason'),
          ),
        ).thenThrow(
          _serverDioException(
            statusCode: 403,
            code: 'FORBIDDEN',
            message: 'Re-request blocked',
            subcode: 'REMOVED_BY_HOST_REREQUEST_BLOCKED',
          ),
        );

        final result = await repo.removeAttendee(
          eventId: eventId,
          joinRequestId: joinRequestId,
          reason: reason,
        );

        expect(result.isLeft(), isTrue);
        final failure =
            result.swap().getOrElse((_) => const UnknownFailure(''));
        expect(failure, isA<ServerFailure>());
        final serverFailure = failure as ServerFailure;
        expect(serverFailure.statusCode, 403);
        expect(serverFailure.code, 'REMOVED_BY_HOST_REREQUEST_BLOCKED');
      },
    );

    test(
      '409 + subcode ALREADY_REMOVED_BY_HOST returns ConflictFailure '
      '(idempotency — benign)',
      () async {
        when(
          () => remote.removeAttendee(
            eventId: any(named: 'eventId'),
            joinRequestId: any(named: 'joinRequestId'),
            reason: any(named: 'reason'),
          ),
        ).thenThrow(
          _serverDioException(
            statusCode: 409,
            code: 'CONFLICT',
            message: 'Already removed',
            subcode: 'ALREADY_REMOVED_BY_HOST',
          ),
        );

        final result = await repo.removeAttendee(
          eventId: eventId,
          joinRequestId: joinRequestId,
          reason: reason,
        );

        expect(result.isLeft(), isTrue);
        final failure =
            result.swap().getOrElse((_) => const UnknownFailure(''));
        expect(failure, isA<ConflictFailure>());
        final conflictFailure = failure as ConflictFailure;
        expect(conflictFailure.subcode, 'ALREADY_REMOVED_BY_HOST');
      },
    );

    test('unknown server error returns ServerFailure', () async {
      when(
        () => remote.removeAttendee(
          eventId: any(named: 'eventId'),
          joinRequestId: any(named: 'joinRequestId'),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(
        _serverDioException(
          statusCode: 500,
          code: 'INTERNAL_SERVER_ERROR',
          message: 'Unexpected error',
        ),
      );

      final result = await repo.removeAttendee(
        eventId: eventId,
        joinRequestId: joinRequestId,
        reason: reason,
      );

      expect(result.isLeft(), isTrue);
      final failure = result.swap().getOrElse((_) => const UnknownFailure(''));
      expect(failure, isA<ServerFailure>());
    });
  });
}
