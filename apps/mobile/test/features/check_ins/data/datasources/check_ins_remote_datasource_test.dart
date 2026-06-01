import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/features/check_ins/data/datasources/check_ins_remote_datasource.dart';
import 'package:tribely/src/features/check_ins/data/models/pending_check_in_model.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockDio extends Mock implements Dio {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _checkInJson(String id) => {
  'id': id,
  'eventId': 'event-1',
  'eventTitle': 'Test Event',
  'hostDisplayName': 'Host Alice',
  'endedAt': '2026-06-01T21:00:00.000Z',
  'createdAt': '2026-06-01T22:00:00.000Z',
};

void main() {
  late MockDio dio;
  late CheckInsRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = CheckInsRemoteDataSourceImpl(dio);
  });

  group('getPending', () {
    test('returns list of PendingCheckInModel on 200', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/me/post-event-check-ins'),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'checkIns': [_checkInJson('ci-1'), _checkInJson('ci-2')],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: '/me/post-event-check-ins'),
        ),
      );

      final result = await dataSource.getPending();

      expect(result, hasLength(2));
      expect(result.first, isA<PendingCheckInModel>());
      expect(result.first.id, 'ci-1');
      expect(result[1].id, 'ci-2');
    });

    test('returns empty list when checkIns array is empty', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/me/post-event-check-ins'),
      ).thenAnswer(
        (_) async => Response(
          data: {'checkIns': <dynamic>[]},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/me/post-event-check-ins'),
        ),
      );

      final result = await dataSource.getPending();

      expect(result, isEmpty);
    });

    test('throws DioException on network error', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/me/post-event-check-ins'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(dataSource.getPending(), throwsA(isA<DioException>()));
    });
  });

  group('acknowledge', () {
    test('completes without error on 200', () async {
      when(
        () => dio.post<void>('/me/post-event-check-ins/ci-1/acknowledge'),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(
            path: '/me/post-event-check-ins/ci-1/acknowledge',
          ),
        ),
      );

      await expectLater(dataSource.acknowledge('ci-1'), completes);
    });

    test('throws DioException on server error', () async {
      when(() => dio.post<void>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/me/post-event-check-ins/ci-1/acknowledge',
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(dataSource.acknowledge('ci-1'), throwsA(isA<DioException>()));
    });
  });

  group('flag', () {
    test('completes without error on 200', () async {
      when(
        () => dio.post<void>(
          '/me/post-event-check-ins/ci-1/flag',
          data: {'reportBody': 'Felt unsafe', 'disclaimerAcknowledged': true},
        ),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(
            path: '/me/post-event-check-ins/ci-1/flag',
          ),
        ),
      );

      await expectLater(
        dataSource.flag('ci-1', 'Felt unsafe', true),
        completes,
      );
    });

    test('throws DioException on server error', () async {
      when(() => dio.post<void>(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/me/post-event-check-ins/ci-1/flag',
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        dataSource.flag('ci-1', 'Felt unsafe', true),
        throwsA(isA<DioException>()),
      );
    });
  });
}
