import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/exceptions.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/check_ins/data/datasources/check_ins_remote_datasource.dart';
import 'package:tribely/src/features/check_ins/data/models/pending_check_in_model.dart';
import 'package:tribely/src/features/check_ins/data/repositories/check_ins_repository_impl.dart';
import 'package:tribely/src/features/check_ins/domain/entities/pending_check_in.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCheckInsRemoteDataSource extends Mock
    implements CheckInsRemoteDataSource {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PendingCheckInModel _makeModel(String id) => PendingCheckInModel(
  id: id,
  eventId: 'event-1',
  eventTitle: 'Test Event',
  hostDisplayName: 'Host Alice',
  endedAt: DateTime(2026, 6, 1, 21),
  createdAt: DateTime(2026, 6, 1, 22),
);

DioException _serverDioException({
  required int statusCode,
  String code = 'SERVER_ERROR',
  String message = 'Server error',
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/me/post-event-check-ins'),
    error: ServerException(message, statusCode: statusCode, code: code),
    type: DioExceptionType.badResponse,
  );
}

DioException _networkDioException() => DioException(
  requestOptions: RequestOptions(path: '/me/post-event-check-ins'),
  error: const NetworkException('No connection'),
  type: DioExceptionType.connectionError,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockCheckInsRemoteDataSource remote;
  late CheckInsRepositoryImpl repository;

  setUp(() {
    remote = MockCheckInsRemoteDataSource();
    repository = CheckInsRepositoryImpl(remote: remote);
  });

  // ---------------------------------------------------------------------------
  // surfacePending
  // ---------------------------------------------------------------------------

  group('surfacePending', () {
    test('returns Right(items) on success', () async {
      when(
        () => remote.getPending(),
      ).thenAnswer((_) async => [_makeModel('ci-1'), _makeModel('ci-2')]);

      final result = await repository.surfacePending();

      expect(result.isRight(), isTrue);
      final items = result.getOrElse((_) => []);
      expect(items, hasLength(2));
      expect(items.first, isA<PendingCheckIn>());
      expect(items.first.id, 'ci-1');
    });

    test('returns Right([]) on empty result', () async {
      when(() => remote.getPending()).thenAnswer((_) async => []);

      final result = await repository.surfacePending();

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => [_makeModel('x').toEntity()]), isEmpty);
    });

    test('returns Left(NetworkFailure) on network error', () async {
      when(() => remote.getPending()).thenThrow(_networkDioException());

      final result = await repository.surfacePending();

      expect(result.isLeft(), isTrue);
      expect(
        result.swap().getOrElse((_) => const UnknownFailure('')),
        isA<NetworkFailure>(),
      );
    });

    test('returns Left(ServerFailure) on server error', () async {
      when(
        () => remote.getPending(),
      ).thenThrow(_serverDioException(statusCode: 500));

      final result = await repository.surfacePending();

      expect(result.isLeft(), isTrue);
      final failure = result.swap().getOrElse((_) => const UnknownFailure(''));
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 500);
    });

    test('returns Left(UnknownFailure) on unexpected exception', () async {
      when(() => remote.getPending()).thenThrow(Exception('unexpected'));

      final result = await repository.surfacePending();

      expect(result.isLeft(), isTrue);
      expect(
        result.swap().getOrElse((_) => const UnknownFailure('')),
        isA<UnknownFailure>(),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // acknowledge
  // ---------------------------------------------------------------------------

  group('acknowledge', () {
    test('returns Right(unit) on success', () async {
      when(() => remote.acknowledge('ci-1')).thenAnswer((_) async {});

      final result = await repository.acknowledge('ci-1');

      expect(result, const Right<Failure, Unit>(unit));
    });

    test('returns Left(NetworkFailure) on network error', () async {
      when(() => remote.acknowledge(any())).thenThrow(_networkDioException());

      final result = await repository.acknowledge('ci-1');

      expect(result.isLeft(), isTrue);
      expect(
        result.swap().getOrElse((_) => const UnknownFailure('')),
        isA<NetworkFailure>(),
      );
    });

    test('returns Left(ServerFailure) on 404', () async {
      when(
        () => remote.acknowledge(any()),
      ).thenThrow(_serverDioException(statusCode: 404, message: 'Not found'));

      final result = await repository.acknowledge('ci-missing');

      expect(result.isLeft(), isTrue);
      final failure = result.swap().getOrElse((_) => const UnknownFailure(''));
      expect(failure, isA<ServerFailure>());
    });
  });

  // ---------------------------------------------------------------------------
  // flag
  // ---------------------------------------------------------------------------

  group('flag', () {
    test('returns Right(unit) on success', () async {
      when(
        () => remote.flag('ci-1', 'Felt unsafe', true),
      ).thenAnswer((_) async {});

      final result = await repository.flag('ci-1', 'Felt unsafe', true);

      expect(result, const Right<Failure, Unit>(unit));
    });

    test('returns Left(NetworkFailure) on network error', () async {
      when(
        () => remote.flag(any(), any(), any()),
      ).thenThrow(_networkDioException());

      final result = await repository.flag('ci-1', 'Felt unsafe', true);

      expect(result.isLeft(), isTrue);
      expect(
        result.swap().getOrElse((_) => const UnknownFailure('')),
        isA<NetworkFailure>(),
      );
    });

    test('returns Left(ServerFailure) on 422', () async {
      when(() => remote.flag(any(), any(), any())).thenThrow(
        _serverDioException(statusCode: 422, message: 'Unprocessable'),
      );

      final result = await repository.flag('ci-1', 'Felt unsafe', true);

      expect(result.isLeft(), isTrue);
      final failure = result.swap().getOrElse((_) => const UnknownFailure(''));
      expect(failure, isA<ServerFailure>());
    });
  });
}
