import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/features/discover/data/datasources/discover_remote_datasource.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockDio extends Mock implements Dio {}

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

/// The inner event shape that EventModel.fromJson expects.
/// Matches eventResponseSchema in
/// apps/api/src/features/events/presentation/http/schemas/event.schemas.ts.
Map<String, dynamic> _innerEventJson({String id = 'evt-42'}) => {
  'id': id,
  'hostUserId': 'usr-1',
  'title': 'Sunset Drinks',
  'description': 'Come watch the sun go down.',
  'venue': {
    'address': '1 Marina Blvd',
    'city': 'Singapore',
    'latitude': 1.2800,
    'longitude': 103.8500,
  },
  'startsAt': '2030-06-15T10:00:00.000Z',
  'endsAt': '2030-06-15T13:00:00.000Z',
  'capacity': 8,
  'category': 'drinks',
  'costSplit': 'own',
  'approvalMode': 'auto',
  'status': 'published',
  'createdAt': '2030-06-01T00:00:00.000Z',
};

/// The WRAPPER shape that GET /events/:id actually returns:
/// { event: {...inner...}, host: { id, displayName, isVerified? } }
/// Defined in eventWithHostResponseSchema (event.schemas.ts:91-94).
///
/// [host] defaults to { id, displayName } without isVerified — parser will
/// default hostIsVerified to false via the ?? false fallback.
Map<String, dynamic> _wrapperJson({
  String id = 'evt-42',
  Map<String, dynamic>? host = const {'id': 'usr-1', 'displayName': 'Alice'},
}) => {'event': _innerEventJson(id: id), 'host': ?host};

/// Synthesise a Dio [Response] for test stubs.
Response<Map<String, dynamic>> _dioResponse(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockDio dio;
  late DiscoverRemoteDatasourceImpl datasource;

  setUp(() {
    dio = _MockDio();
    datasource = DiscoverRemoteDatasourceImpl(dio);
  });

  group('getEventDetail — wrapper contract', () {
    test(
      'unwraps { event, host } wrapper → returns EventModel with correct id',
      () async {
        // Arrange: API returns the wrapped shape.
        when(
          () => dio.get<Map<String, dynamic>>(
            '/events/evt-42',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).thenAnswer((_) async => _dioResponse(_wrapperJson()));

        // Act.
        final model = await datasource.getEventDetail('evt-42');

        // Assert: inner fields parsed correctly.
        expect(model.id, 'evt-42');
        expect(model.hostUserId, 'usr-1');
        expect(model.title, 'Sunset Drinks');
        expect(model.venue.city, 'Singapore');
      },
    );

    test('host.displayName is synthesised onto the model as hostDisplayName, '
        'absent isVerified defaults to false', () async {
      // Arrange: wrapper with host.displayName present but no isVerified field.
      when(
        () => dio.get<Map<String, dynamic>>(
          '/events/evt-42',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer(
        (_) async => _dioResponse(
          _wrapperJson(host: {'id': 'usr-1', 'displayName': 'Alice'}),
        ),
      );

      // Act.
      final model = await datasource.getEventDetail('evt-42');

      // Assert: host display name and isVerified (defaults false) flow through.
      expect(model.hostDisplayName, 'Alice');
      expect(model.hostIsVerified, false);
    });

    test(
      'host.isVerified = true in wrapper → model.hostIsVerified == true',
      () async {
        // Arrange: wrapper carries host.isVerified: true.
        when(
          () => dio.get<Map<String, dynamic>>(
            '/events/evt-42',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).thenAnswer(
          (_) async => _dioResponse(
            _wrapperJson(
              host: {'id': 'usr-1', 'displayName': 'Alice', 'isVerified': true},
            ),
          ),
        );

        // Act.
        final model = await datasource.getEventDetail('evt-42');

        // Assert: verified flag flows through.
        expect(model.hostIsVerified, true);
        expect(model.hostDisplayName, 'Alice');
      },
    );

    test(
      'absent host sibling → hostDisplayName is null and hostIsVerified is false (graceful fallback)',
      () async {
        // Arrange: wrapper with no host key.
        when(
          () => dio.get<Map<String, dynamic>>(
            '/events/evt-42',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).thenAnswer((_) async => _dioResponse(_wrapperJson(host: null)));

        // Act.
        final model = await datasource.getEventDetail('evt-42');

        // Assert: graceful null for displayName; false for isVerified — no throw.
        expect(model.hostDisplayName, isNull);
        expect(model.hostIsVerified, false);
      },
    );

    test(
      'bare inner shape (no wrapper) throws a cast error — pins that detail '
      'responses are always wrapped and must never pass the raw inner shape',
      () async {
        // Arrange: simulate a caller accidentally passing the bare inner shape
        // (i.e., pre-fix behaviour where response.data! was passed directly to
        // EventModel.fromJson). The inner map has no 'event' key, so
        // response.data!['event'] returns null and the cast to Map<String,dynamic>
        // throws a TypeError — exactly the bug TRI-27 cycle-6 fixed.
        when(
          () => dio.get<Map<String, dynamic>>(
            '/events/evt-bare',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).thenAnswer(
          (_) async => _dioResponse(_innerEventJson(id: 'evt-bare')),
        );

        // Act + Assert: accessing ['event'] on the inner map returns null, and
        // the subsequent `as Map<String,dynamic>` cast must throw.
        await expectLater(
          () => datasource.getEventDetail('evt-bare'),
          throwsA(isA<TypeError>()),
        );
      },
    );
  });
}
