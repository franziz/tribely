import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/exceptions.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/events/data/datasources/event_draft_local_datasource.dart';
import 'package:tribely/src/features/events/data/datasources/event_remote_datasource.dart';
import 'package:tribely/src/features/events/data/models/create_event_params_model.dart';
import 'package:tribely/src/features/events/data/models/event_draft_model.dart';
import 'package:tribely/src/features/events/data/models/event_model.dart';
import 'package:tribely/src/features/events/data/repositories/event_repository_impl.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';
import 'package:tribely/src/features/events/domain/entities/event_draft.dart';
import 'package:tribely/src/features/events/domain/repositories/event_repository.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockEventRemoteDatasource extends Mock
    implements EventRemoteDatasource {}

class _MockEventDraftLocalDatasource extends Mock
    implements EventDraftLocalDatasource {}

// ---------------------------------------------------------------------------
// Fakes — required by mocktail for any() / captureAny() on these types
// ---------------------------------------------------------------------------

class _FakeCreateEventParamsModel extends Fake
    implements CreateEventParamsModel {}

class _FakeEventDraftModel extends Fake implements EventDraftModel {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a [DioException] whose [DioException.error] is [inner]. The
/// repository's _mapDioError dispatch key is `e.error`, not the DioException
/// itself — so the error payload must be set correctly.
DioException _dioWith(Object inner) {
  return DioException(requestOptions: RequestOptions(), error: inner);
}

/// Build a [DioException] that also carries a [Response] with [responseData].
///
/// Used for 422 tests where _mapDioError reads `e.response?.data` to extract
/// `error.details.subcode` — the _ErrorInterceptor in production attaches the
/// full response, so both [error] and [response] are present.
DioException _dioWithResponse(Object inner, Map<String, dynamic> responseData) {
  final opts = RequestOptions(path: '/events');
  return DioException(
    requestOptions: opts,
    error: inner,
    response: Response<Map<String, dynamic>>(
      requestOptions: opts,
      data: responseData,
      statusCode: (inner is ServerException) ? inner.statusCode : 422,
    ),
  );
}

/// Minimal [EventModel] for happy-path assertions.
final _stubModel = EventModel(
  id: 'evt-1',
  hostUserId: 'usr-1',
  title: 'Test Event',
  description: 'A test',
  venue: const EventVenueModel(
    address: '1 Marina Blvd',
    city: 'Singapore',
    latitude: 1.28,
    longitude: 103.85,
    category: 'restaurant',
  ),
  startsAt: DateTime(2030, 1, 1, 18),
  endsAt: DateTime(2030, 1, 1, 21),
  capacity: 10,
  category: EventCategory.drinks,
  costNotes: null,
  approvalMode: 'auto',
  status: 'published',
  createdAt: DateTime(2030, 1, 1),
  hostIsVerified: false,
);

/// Minimal [CreateEventParams] for triggering the createEvent path.
final _stubParams = CreateEventParams(
  title: 'Test Event',
  category: EventCategory.drinks,
  venueName: '1 Marina Blvd',
  venueCategory: 'restaurant',
  latitude: 1.28,
  longitude: 103.85,
  startsAt: DateTime(2030, 1, 1, 18),
  endsAt: DateTime(2030, 1, 1, 21),
  capacity: 10,
  approvalMode: 'auto',
  description: 'A test description with enough characters',
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCreateEventParamsModel());
    registerFallbackValue(_FakeEventDraftModel());
  });

  late _MockEventRemoteDatasource remote;
  late _MockEventDraftLocalDatasource local;
  late EventRepositoryImpl repo;

  setUp(() {
    remote = _MockEventRemoteDatasource();
    local = _MockEventDraftLocalDatasource();
    repo = EventRepositoryImpl(remote: remote, local: local);
  });

  // ---------------------------------------------------------------------------
  // createEvent — remote success
  // ---------------------------------------------------------------------------
  group('createEvent — success', () {
    test('remote returns model → Right(Event) with correct id', () async {
      when(() => remote.createEvent(any())).thenAnswer((_) async => _stubModel);

      final result = await repo.createEvent(_stubParams);

      expect(result.isRight(), isTrue);
      final event = (result as Right<Failure, Event>).value;
      expect(event.id, 'evt-1');
      expect(event.title, 'Test Event');
      expect(event.hostId, 'usr-1');
    });
  });

  // ---------------------------------------------------------------------------
  // createEvent — Dio / server error mapping
  // ---------------------------------------------------------------------------
  group('createEvent — Dio error mapping', () {
    test(
      'ServerException(400, VALIDATION) → Left(ValidationFailure) with message',
      () async {
        final ex = const ServerException(
          'Title required',
          statusCode: 400,
          code: 'VALIDATION',
        );
        when(() => remote.createEvent(any())).thenThrow(_dioWith(ex));

        final result = await repo.createEvent(_stubParams);

        expect(result.isLeft(), isTrue);
        final failure = (result as Left<Failure, Event>).value;
        expect(failure, isA<ValidationFailure>());
        expect(failure.message, 'Title required');
      },
    );

    test('ServerException(401) → Left(AuthFailure)', () async {
      final ex = const ServerException('Unauthorized', statusCode: 401);
      when(() => remote.createEvent(any())).thenThrow(_dioWith(ex));

      final result = await repo.createEvent(_stubParams);

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<AuthFailure>());
    });

    test(
      'ServerException(403, EMAIL_NOT_VERIFIED) → Left(EmailNotVerifiedFailure)',
      () async {
        final ex = const ServerException(
          'Email not verified',
          statusCode: 403,
          code: 'EMAIL_NOT_VERIFIED',
        );
        when(() => remote.createEvent(any())).thenThrow(_dioWith(ex));

        final result = await repo.createEvent(_stubParams);

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<EmailNotVerifiedFailure>());
      },
    );

    test(
      'ServerException(403, OTHER code) → Left(ServerFailure) with status 403',
      () async {
        final ex = const ServerException(
          'Forbidden',
          statusCode: 403,
          code: 'SOME_OTHER_CODE',
        );
        when(() => remote.createEvent(any())).thenThrow(_dioWith(ex));

        final result = await repo.createEvent(_stubParams);

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value;
        expect(failure, isA<ServerFailure>());
        expect((failure as ServerFailure).statusCode, 403);
      },
    );

    test(
      'ServerException(429) → Left(ServerFailure) with status 429 + message',
      () async {
        final ex = const ServerException('Too many requests', statusCode: 429);
        when(() => remote.createEvent(any())).thenThrow(_dioWith(ex));

        final result = await repo.createEvent(_stubParams);

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value;
        expect(failure, isA<ServerFailure>());
        expect((failure as ServerFailure).statusCode, 429);
        expect(failure.message, 'Too many requests');
      },
    );

    test(
      'ServerException(422, FIRST_EVENT_MUST_BE_PUBLIC, category_not_public) '
      '→ Left(FirstEventMustBePublicFailure) with reason=category_not_public',
      () async {
        // The interceptor wraps the error as ServerException(422) and also
        // attaches the raw response. _mapDioError reads both.
        final ex = const ServerException(
          'First event must be at a public venue.',
          statusCode: 422,
          code: 'UNPROCESSABLE',
        );
        final responseBody = {
          'error': {
            'message': 'First event must be at a public venue.',
            'code': 'UNPROCESSABLE',
            'details': {
              'subcode': 'FIRST_EVENT_MUST_BE_PUBLIC',
              'reason': 'category_not_public',
            },
          },
        };
        when(
          () => remote.createEvent(any()),
        ).thenThrow(_dioWithResponse(ex, responseBody));

        final result = await repo.createEvent(_stubParams);

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value;
        expect(failure, isA<FirstEventMustBePublicFailure>());
        expect(
          (failure as FirstEventMustBePublicFailure).reason,
          'category_not_public',
        );
      },
    );

    test(
      'ServerException(422, FIRST_EVENT_MUST_BE_PUBLIC, keyword_match) '
      '→ Left(FirstEventMustBePublicFailure) with reason=keyword_match',
      () async {
        final ex = const ServerException(
          'First event must be at a public venue.',
          statusCode: 422,
          code: 'UNPROCESSABLE',
        );
        final responseBody = {
          'error': {
            'message': 'First event must be at a public venue.',
            'code': 'UNPROCESSABLE',
            'details': {
              'subcode': 'FIRST_EVENT_MUST_BE_PUBLIC',
              'reason': 'keyword_match',
            },
          },
        };
        when(
          () => remote.createEvent(any()),
        ).thenThrow(_dioWithResponse(ex, responseBody));

        final result = await repo.createEvent(_stubParams);

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value;
        expect(failure, isA<FirstEventMustBePublicFailure>());
        expect(
          (failure as FirstEventMustBePublicFailure).reason,
          'keyword_match',
        );
      },
    );

    test('ServerException(422) without FIRST_EVENT_MUST_BE_PUBLIC subcode '
        '→ Left(ServerFailure) with status 422', () async {
      // A 422 with a different subcode (e.g. generic validation) must fall
      // through to ServerFailure, not FirstEventMustBePublicFailure.
      final ex = const ServerException(
        'Unprocessable entity',
        statusCode: 422,
        code: 'UNPROCESSABLE',
      );
      final responseBody = {
        'error': {
          'message': 'Unprocessable entity',
          'code': 'UNPROCESSABLE',
          'details': {'subcode': 'SOME_OTHER_SUBCODE'},
        },
      };
      when(
        () => remote.createEvent(any()),
      ).thenThrow(_dioWithResponse(ex, responseBody));

      final result = await repo.createEvent(_stubParams);

      expect(result.isLeft(), isTrue);
      final failure = (result as Left).value;
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 422);
    });

    test(
      'ServerException(500) → Left(ServerFailure) with status 500',
      () async {
        final ex = const ServerException('Internal error', statusCode: 500);
        when(() => remote.createEvent(any())).thenThrow(_dioWith(ex));

        final result = await repo.createEvent(_stubParams);

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value;
        expect(failure, isA<ServerFailure>());
        expect((failure as ServerFailure).statusCode, 500);
      },
    );

    test('NetworkException → Left(NetworkFailure)', () async {
      final ex = const NetworkException('No connection');
      when(() => remote.createEvent(any())).thenThrow(_dioWith(ex));

      final result = await repo.createEvent(_stubParams);

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<NetworkFailure>());
    });

    test('arbitrary Exception → Left(UnknownFailure)', () async {
      when(
        () => remote.createEvent(any()),
      ).thenThrow(Exception('Something unexpected'));

      final result = await repo.createEvent(_stubParams);

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<UnknownFailure>());
    });
  });

  // ---------------------------------------------------------------------------
  // loadDraft
  // ---------------------------------------------------------------------------
  group('loadDraft', () {
    test('local returns null → Right(null)', () async {
      when(() => local.load()).thenAnswer((_) async => null);

      final result = await repo.loadDraft();

      expect(result, const Right<Failure, EventDraft?>(null));
    });

    test(
      'local returns a model → Right(EventDraft) with matching fields',
      () async {
        const model = EventDraftModel(
          schemaVersion: 1,
          title: 'Draft Title',
          currentStep: 2,
          lastUpdatedAt: '2030-01-01T10:00:00.000',
        );
        when(() => local.load()).thenAnswer((_) async => model);

        final result = await repo.loadDraft();

        expect(result.isRight(), isTrue);
        final draft = (result as Right<Failure, EventDraft?>).value;
        expect(draft, isNotNull);
        expect(draft!.title, 'Draft Title');
        expect(draft.currentStep, 2);
      },
    );

    test('local throws Exception → Left(UnknownFailure)', () async {
      when(() => local.load()).thenThrow(Exception('Storage error'));

      final result = await repo.loadDraft();

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<UnknownFailure>());
    });
  });

  // ---------------------------------------------------------------------------
  // saveDraft
  // ---------------------------------------------------------------------------
  group('saveDraft', () {
    const draft = EventDraft(title: 'My Draft', currentStep: 1);

    test('local succeeds → Right(null)', () async {
      when(() => local.save(any())).thenAnswer((_) async {});

      final result = await repo.saveDraft(draft);

      expect(result, const Right<Failure, void>(null));
    });

    test('local throws Exception → Left(UnknownFailure)', () async {
      when(() => local.save(any())).thenThrow(Exception('Write failed'));

      final result = await repo.saveDraft(draft);

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<UnknownFailure>());
    });
  });

  // ---------------------------------------------------------------------------
  // clearDraft
  // ---------------------------------------------------------------------------
  group('clearDraft', () {
    test('local succeeds → Right(null)', () async {
      when(() => local.clear()).thenAnswer((_) async {});

      final result = await repo.clearDraft();

      expect(result, const Right<Failure, void>(null));
    });

    test('local throws Exception → Left(UnknownFailure)', () async {
      when(() => local.clear()).thenThrow(Exception('Delete failed'));

      final result = await repo.clearDraft();

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<UnknownFailure>());
    });
  });
}
