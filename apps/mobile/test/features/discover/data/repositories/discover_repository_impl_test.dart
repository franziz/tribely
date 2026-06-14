import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/exceptions.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:tribely/src/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:tribely/src/features/discover/domain/entities/discover_filters.dart';
import 'package:tribely/src/features/discover/domain/entities/event_page.dart';
import 'package:tribely/src/features/events/data/models/event_model.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';

// ---------------------------------------------------------------------------
// Mocks + fakes
// ---------------------------------------------------------------------------

class _MockDiscoverRemoteDatasource extends Mock
    implements DiscoverRemoteDatasource {}

class _FakeDiscoverFilters extends Fake implements DiscoverFilters {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a [DioException] whose [DioException.error] is [inner].
DioException _dioWith(Object inner) =>
    DioException(requestOptions: RequestOptions(), error: inner);

/// Minimal [EventVenueModel] for test stubs.
const _venueModel = EventVenueModel(
  address: '1 Marina Blvd',
  city: 'Singapore',
  latitude: 1.28,
  longitude: 103.85,
  category: 'restaurant',
);

/// Minimal [EventModel] for happy-path assertions.
final _stubModel = EventModel(
  id: 'evt-1',
  hostUserId: 'usr-1',
  title: 'Sunset Drinks',
  description: null,
  venue: _venueModel,
  startsAt: DateTime(2030, 6, 15, 18),
  endsAt: DateTime(2030, 6, 15, 21),
  capacity: 8,
  category: EventCategory.drinks,
  costNotes: null,
  approvalMode: 'auto',
  status: 'published',
  createdAt: DateTime(2030, 6, 1),
  hostIsVerified: false,
);

final _stubPageResponse = EventPageResponse(
  events: [_stubModel],
  nextCursor: 'cursor-abc',
);

final _stubFilters = const DiscoverFilters();

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDiscoverFilters());
  });

  late _MockDiscoverRemoteDatasource remote;
  late DiscoverRepositoryImpl repo;

  setUp(() {
    remote = _MockDiscoverRemoteDatasource();
    repo = DiscoverRepositoryImpl(remote: remote);
  });

  // ---------------------------------------------------------------------------
  // browseEvents — happy path
  // ---------------------------------------------------------------------------
  group('browseEvents — success', () {
    test(
      'remote returns page response → Right(EventPage) with events and cursor',
      () async {
        when(
          () => remote.browseEvents(any()),
        ).thenAnswer((_) async => _stubPageResponse);

        final result = await repo.browseEvents(_stubFilters);

        expect(result.isRight(), isTrue);
        final page = (result as Right<Failure, EventPage>).value;
        expect(page.events.length, 1);
        expect(page.events.first.id, 'evt-1');
        expect(page.events.first.hostId, 'usr-1');
        expect(page.nextCursor, 'cursor-abc');
        expect(page.hasMore, isTrue);
      },
    );

    test(
      'empty events + null cursor → Right(EventPage) with hasMore false',
      () async {
        when(() => remote.browseEvents(any())).thenAnswer(
          (_) async => const EventPageResponse(events: [], nextCursor: null),
        );

        final result = await repo.browseEvents(_stubFilters);

        expect(result.isRight(), isTrue);
        final page = (result as Right<Failure, EventPage>).value;
        expect(page.events, isEmpty);
        expect(page.nextCursor, isNull);
        expect(page.hasMore, isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // browseEvents — error mapping
  // ---------------------------------------------------------------------------
  group('browseEvents — error mapping', () {
    test('ServerException(401) → Left(AuthFailure)', () async {
      when(() => remote.browseEvents(any())).thenThrow(
        _dioWith(const ServerException('Unauthorized', statusCode: 401)),
      );

      final result = await repo.browseEvents(_stubFilters);

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<AuthFailure>());
    });

    test(
      'ServerException(500) → Left(ServerFailure) with statusCode 500',
      () async {
        when(() => remote.browseEvents(any())).thenThrow(
          _dioWith(const ServerException('Internal error', statusCode: 500)),
        );

        final result = await repo.browseEvents(_stubFilters);

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value;
        expect(failure, isA<ServerFailure>());
        expect((failure as ServerFailure).statusCode, 500);
      },
    );

    test('NetworkException → Left(NetworkFailure)', () async {
      when(
        () => remote.browseEvents(any()),
      ).thenThrow(_dioWith(const NetworkException('No connection')));

      final result = await repo.browseEvents(_stubFilters);

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<NetworkFailure>());
    });

    test('arbitrary Exception → Left(UnknownFailure)', () async {
      when(() => remote.browseEvents(any())).thenThrow(Exception('Unexpected'));

      final result = await repo.browseEvents(_stubFilters);

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<UnknownFailure>());
    });
  });

  // ---------------------------------------------------------------------------
  // getEventDetail — happy path
  // ---------------------------------------------------------------------------
  group('getEventDetail — success', () {
    test('remote returns model → Right(Event) with mapped fields', () async {
      when(
        () => remote.getEventDetail(any()),
      ).thenAnswer((_) async => _stubModel);

      final result = await repo.getEventDetail('evt-1');

      expect(result.isRight(), isTrue);
      final event = (result as Right<Failure, Event>).value;
      expect(event.id, 'evt-1');
      expect(event.hostId, 'usr-1');
      expect(event.title, 'Sunset Drinks');
    });
  });

  // ---------------------------------------------------------------------------
  // getEventDetail — error mapping
  // ---------------------------------------------------------------------------
  group('getEventDetail — error mapping', () {
    test('ServerException(404) → Left(NotFoundFailure)', () async {
      when(() => remote.getEventDetail(any())).thenThrow(
        _dioWith(const ServerException('Event not found', statusCode: 404)),
      );

      final result = await repo.getEventDetail('evt-missing');

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<NotFoundFailure>());
    });

    test('ServerException(401) → Left(AuthFailure)', () async {
      when(() => remote.getEventDetail(any())).thenThrow(
        _dioWith(const ServerException('Unauthorized', statusCode: 401)),
      );

      final result = await repo.getEventDetail('evt-1');

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<AuthFailure>());
    });

    test('ServerException(500) → Left(ServerFailure)', () async {
      when(() => remote.getEventDetail(any())).thenThrow(
        _dioWith(const ServerException('Internal error', statusCode: 500)),
      );

      final result = await repo.getEventDetail('evt-1');

      expect(result.isLeft(), isTrue);
      final failure = (result as Left).value;
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 500);
    });

    test('NetworkException → Left(NetworkFailure)', () async {
      when(
        () => remote.getEventDetail(any()),
      ).thenThrow(_dioWith(const NetworkException('Offline')));

      final result = await repo.getEventDetail('evt-1');

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<NetworkFailure>());
    });
  });
}
