import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/features/events/data/datasources/mapbox_place_search_remote_datasource.dart';
import 'package:tribely/src/features/events/data/exceptions/place_search_exceptions.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockDio extends Mock implements Dio {}

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

/// Minimal Mapbox /suggest response body.
Map<String, dynamic> _suggestResponseBody({
  String mapboxId = 'place.abc123',
  List<dynamic>? poiCategory = const ['food_and_drink'],
}) => {
  'suggestions': [
    {
      'mapbox_id': mapboxId,
      'name': 'Lau Pa Sat',
      'place_formatted': '18 Raffles Quay, Singapore 048582',
      if (poiCategory != null) 'poi_category': poiCategory,
    },
  ],
};

/// Minimal Mapbox /retrieve response body.
/// NOTE: coordinates are [longitude, latitude] per GeoJSON spec.
Map<String, dynamic> _retrieveResponseBody({
  double lng = 103.8500,
  double lat = 1.2800,
  String mapboxId = 'place.abc123',
}) => {
  'features': [
    {
      'properties': {
        'mapbox_id': mapboxId,
        'name': 'Lau Pa Sat',
        'full_address': '18 Raffles Quay, Singapore 048582',
        'poi_category': ['food_and_drink'],
      },
      'geometry': {
        'type': 'Point',
        // GeoJSON: longitude first, then latitude.
        'coordinates': [lng, lat],
      },
    },
  ],
};

/// Build a Dio [Response] wrapping [data] with a 200 status.
Response<Map<String, dynamic>> _ok(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );

/// Build a Dio [Response] with an error [statusCode] and optional [body].
Response<dynamic> _errorResponse(int statusCode, {dynamic body}) =>
    Response<dynamic>(
      data: body,
      statusCode: statusCode,
      requestOptions: RequestOptions(path: ''),
    );

/// Build a [DioException] backed by [response].
DioException _dioHttpException(Response<dynamic> response) => DioException(
  requestOptions: response.requestOptions,
  response: response,
  type: DioExceptionType.badResponse,
);

/// Build a network-level [DioException] (no response object).
DioException _networkException() => DioException(
  requestOptions: RequestOptions(path: ''),
  type: DioExceptionType.connectionError,
  message: 'Connection refused',
);

// ---------------------------------------------------------------------------
// Helpers to set up Dio mock for GET requests (mocktail requires all named
// params to be matched; use any() for the ones we don't care about).
// ---------------------------------------------------------------------------

void _stubGet(
  _MockDio dio,
  String url,
  Map<String, dynamic> qp,
  Response<dynamic> response,
) {
  when(
    () => dio.get<Map<String, dynamic>>(
      url,
      queryParameters: qp,
      options: any(named: 'options'),
      cancelToken: any(named: 'cancelToken'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenAnswer((_) async => response as Response<Map<String, dynamic>>);
}

void _stubGetThrow(
  _MockDio dio,
  String url,
  Map<String, dynamic> qp,
  Object error,
) {
  when(
    () => dio.get<Map<String, dynamic>>(
      url,
      queryParameters: qp,
      options: any(named: 'options'),
      cancelToken: any(named: 'cancelToken'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenThrow(error);
}

// ---------------------------------------------------------------------------
// Expected query-param maps for verification tests.
// These mirror the constants in place_search_constants.dart exactly.
// ---------------------------------------------------------------------------

Map<String, dynamic> _suggestQp({
  String query = 'lau pa sat',
  String sessionToken = 'sess-abc',
}) => {
  'q': query,
  'session_token': sessionToken,
  'access_token': '', // String.fromEnvironment returns '' in test env
  'country': 'SG',
  'language': 'en',
  'proximity': '103.8198,1.3521',
  'limit': 8,
  'types': 'poi,address,place',
};

Map<String, dynamic> _retrieveQp({String sessionToken = 'sess-abc'}) => {
  'session_token': sessionToken,
  'access_token': '', // String.fromEnvironment returns '' in test env
};

const String _kBaseUrl = 'https://api.mapbox.com/search/searchbox/v1';

void main() {
  late _MockDio dio;
  late MapboxPlaceSearchRemoteDatasourceImpl datasource;

  setUp(() {
    dio = _MockDio();
    datasource = MapboxPlaceSearchRemoteDatasourceImpl(dio);
  });

  // =========================================================================
  // suggest — request shape
  // =========================================================================
  group('suggest — request shape', () {
    test(
      'sends correct URL and required query params (country, language, proximity, session_token, q)',
      () async {
        final qp = _suggestQp();
        _stubGet(dio, '$_kBaseUrl/suggest', qp, _ok(_suggestResponseBody()));

        await datasource.suggest(query: 'lau pa sat', sessionToken: 'sess-abc');

        // Verify the request was made with the exact query params.
        verify(
          () => dio.get<Map<String, dynamic>>(
            '$_kBaseUrl/suggest',
            queryParameters: qp,
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).called(1);
      },
    );

    test('returns list of PlaceSuggestionModel on success', () async {
      _stubGet(
        dio,
        '$_kBaseUrl/suggest',
        _suggestQp(),
        _ok(_suggestResponseBody()),
      );

      final models = await datasource.suggest(
        query: 'lau pa sat',
        sessionToken: 'sess-abc',
      );

      expect(models.length, 1);
      expect(models.first.mapboxId, 'place.abc123');
      expect(models.first.name, 'Lau Pa Sat');
      expect(models.first.rawCategory, 'food_and_drink');
    });
  });

  // =========================================================================
  // retrieve — request shape
  // =========================================================================
  group('retrieve — request shape', () {
    test(
      'sends correct URL with mapbox_id in path and session_token in QP',
      () async {
        const mapboxId = 'place.abc123';
        final qp = _retrieveQp();
        _stubGet(
          dio,
          '$_kBaseUrl/retrieve/$mapboxId',
          qp,
          _ok(_retrieveResponseBody()),
        );

        await datasource.retrieve(mapboxId: mapboxId, sessionToken: 'sess-abc');

        verify(
          () => dio.get<Map<String, dynamic>>(
            '$_kBaseUrl/retrieve/$mapboxId',
            queryParameters: qp,
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).called(1);
      },
    );

    test(
      'REGRESSION: GeoJSON [lng=103.85, lat=1.28] → entity latitude=1.28, longitude=103.85',
      () async {
        // This is the primary coordinate-flip regression guard.
        // Input: Mapbox GeoJSON coordinates [longitude=103.85, latitude=1.28]
        // Expected: entity.latitude == 1.28 (index 1), entity.longitude == 103.85 (index 0)
        const mapboxId = 'place.sg';
        _stubGet(
          dio,
          '$_kBaseUrl/retrieve/$mapboxId',
          _retrieveQp(),
          _ok(
            _retrieveResponseBody(lng: 103.85, lat: 1.28, mapboxId: mapboxId),
          ),
        );

        final model = await datasource.retrieve(
          mapboxId: mapboxId,
          sessionToken: 'sess-abc',
        );
        final entity = model.toEntity();

        expect(
          entity.latitude,
          1.28,
          reason: 'latitude must come from coordinates[1], not coordinates[0]',
        );
        expect(
          entity.longitude,
          103.85,
          reason: 'longitude must come from coordinates[0], not coordinates[1]',
        );
      },
    );
  });

  // =========================================================================
  // suggest — error mapping
  // =========================================================================
  group('suggest — error mapping', () {
    test('HTTP 429 → throws QuotaExhaustedException', () async {
      _stubGetThrow(
        dio,
        '$_kBaseUrl/suggest',
        _suggestQp(),
        _dioHttpException(_errorResponse(429)),
      );

      await expectLater(
        () => datasource.suggest(query: 'lau pa sat', sessionToken: 'sess-abc'),
        throwsA(isA<QuotaExhaustedException>()),
      );
    });

    test(
      'HTTP 403 with "quota" in body → throws QuotaExhaustedException',
      () async {
        _stubGetThrow(
          dio,
          '$_kBaseUrl/suggest',
          _suggestQp(),
          _dioHttpException(_errorResponse(403, body: 'quota exceeded')),
        );

        await expectLater(
          () =>
              datasource.suggest(query: 'lau pa sat', sessionToken: 'sess-abc'),
          throwsA(isA<QuotaExhaustedException>()),
        );
      },
    );

    test(
      'HTTP 403 with "billing" in body → throws QuotaExhaustedException',
      () async {
        _stubGetThrow(
          dio,
          '$_kBaseUrl/suggest',
          _suggestQp(),
          _dioHttpException(
            _errorResponse(403, body: {'message': 'billing issue'}),
          ),
        );

        await expectLater(
          () =>
              datasource.suggest(query: 'lau pa sat', sessionToken: 'sess-abc'),
          throwsA(isA<QuotaExhaustedException>()),
        );
      },
    );

    test('HTTP 5xx → throws ProviderException', () async {
      _stubGetThrow(
        dio,
        '$_kBaseUrl/suggest',
        _suggestQp(),
        _dioHttpException(_errorResponse(503)),
      );

      await expectLater(
        () => datasource.suggest(query: 'lau pa sat', sessionToken: 'sess-abc'),
        throwsA(isA<ProviderException>()),
      );
    });

    test(
      'network-level DioException (no response) → bubbles through as DioException',
      () async {
        _stubGetThrow(
          dio,
          '$_kBaseUrl/suggest',
          _suggestQp(),
          _networkException(),
        );

        await expectLater(
          () =>
              datasource.suggest(query: 'lau pa sat', sessionToken: 'sess-abc'),
          throwsA(isA<DioException>()),
        );
      },
    );
  });

  // =========================================================================
  // retrieve — error mapping
  // =========================================================================
  group('retrieve — error mapping', () {
    test('HTTP 429 → throws QuotaExhaustedException', () async {
      _stubGetThrow(
        dio,
        '$_kBaseUrl/retrieve/place.abc',
        _retrieveQp(),
        _dioHttpException(_errorResponse(429)),
      );

      await expectLater(
        () => datasource.retrieve(
          mapboxId: 'place.abc',
          sessionToken: 'sess-abc',
        ),
        throwsA(isA<QuotaExhaustedException>()),
      );
    });

    test('HTTP 5xx → throws ProviderException', () async {
      _stubGetThrow(
        dio,
        '$_kBaseUrl/retrieve/place.abc',
        _retrieveQp(),
        _dioHttpException(_errorResponse(500)),
      );

      await expectLater(
        () => datasource.retrieve(
          mapboxId: 'place.abc',
          sessionToken: 'sess-abc',
        ),
        throwsA(isA<ProviderException>()),
      );
    });

    test(
      'network-level DioException (no response) → bubbles through as DioException',
      () async {
        _stubGetThrow(
          dio,
          '$_kBaseUrl/retrieve/place.abc',
          _retrieveQp(),
          _networkException(),
        );

        await expectLater(
          () => datasource.retrieve(
            mapboxId: 'place.abc',
            sessionToken: 'sess-abc',
          ),
          throwsA(isA<DioException>()),
        );
      },
    );
  });
}
