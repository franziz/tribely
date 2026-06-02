import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/events/data/datasources/mapbox_place_search_remote_datasource.dart';
import 'package:tribely/src/features/events/data/exceptions/place_search_exceptions.dart';
import 'package:tribely/src/features/events/data/models/place_details_model.dart';
import 'package:tribely/src/features/events/data/models/place_suggestion_model.dart';
import 'package:tribely/src/features/events/data/repositories/place_search_repository_impl.dart';
import 'package:tribely/src/features/events/domain/entities/place_details.dart';
import 'package:tribely/src/features/events/domain/entities/place_suggestion.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockMapboxDatasource extends Mock
    implements MapboxPlaceSearchRemoteDatasource {}

// ---------------------------------------------------------------------------
// Stub data
// ---------------------------------------------------------------------------

const _stubSuggestionModel = PlaceSuggestionModel(
  mapboxId: 'place.abc',
  name: 'Lau Pa Sat',
  placeFormatted: '18 Raffles Quay, Singapore',
  rawCategory: 'food_and_drink',
);

const _stubDetailsModel = PlaceDetailsModel(
  mapboxId: 'place.abc',
  name: 'Lau Pa Sat',
  formattedAddress: '18 Raffles Quay, Singapore 048582',
  longitude: 103.85,
  latitude: 1.28,
  rawCategory: 'food_and_drink',
);

/// Build a network-level [DioException] (no response — simulates connection failure).
DioException _networkDioException() => DioException(
  requestOptions: RequestOptions(path: '/suggest'),
  type: DioExceptionType.connectionError,
  message: 'Connection refused',
);

void main() {
  late _MockMapboxDatasource datasource;
  late PlaceSearchRepositoryImpl repo;

  setUp(() {
    datasource = _MockMapboxDatasource();
    repo = PlaceSearchRepositoryImpl(datasource: datasource);
  });

  // =========================================================================
  // suggest
  // =========================================================================
  group('suggest — success', () {
    test('datasource returns models → Right([PlaceSuggestion])', () async {
      when(
        () => datasource.suggest(
          query: any(named: 'query'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenAnswer((_) async => [_stubSuggestionModel]);

      final result = await repo.suggest(
        query: 'lau pa sat',
        sessionToken: 'token-1',
      );

      expect(result.isRight(), isTrue);
      final suggestions =
          (result as Right<Failure, List<PlaceSuggestion>>).value;
      expect(suggestions.length, 1);
      expect(suggestions.first.providerPlaceId, 'place.abc');
      expect(suggestions.first.name, 'Lau Pa Sat');
    });

    test('datasource returns empty list → Right([])', () async {
      when(
        () => datasource.suggest(
          query: any(named: 'query'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenAnswer((_) async => []);

      final result = await repo.suggest(
        query: 'nonexistent place xyz',
        sessionToken: 'token-1',
      );

      expect(result.isRight(), isTrue);
      expect((result as Right<Failure, List<PlaceSuggestion>>).value, isEmpty);
    });
  });

  group('suggest — failure mapping', () {
    test(
      'QuotaExhaustedException (HTTP 429) → Left(QuotaExhaustedFailure)',
      () async {
        when(
          () => datasource.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenThrow(
          const QuotaExhaustedException(
            'Mapbox rate limit exceeded (HTTP 429)',
          ),
        );

        final result = await repo.suggest(
          query: 'test',
          sessionToken: 'token-1',
        );

        expect(result.isLeft(), isTrue);
        expect(
          (result as Left<Failure, List<PlaceSuggestion>>).value,
          isA<QuotaExhaustedFailure>(),
        );
      },
    );

    test(
      'QuotaExhaustedException (HTTP 403 + quota body) → Left(QuotaExhaustedFailure)',
      () async {
        when(
          () => datasource.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenThrow(
          const QuotaExhaustedException('Mapbox quota exhausted (HTTP 403)'),
        );

        final result = await repo.suggest(
          query: 'test',
          sessionToken: 'token-1',
        );

        expect(result.isLeft(), isTrue);
        expect(
          (result as Left<Failure, List<PlaceSuggestion>>).value,
          isA<QuotaExhaustedFailure>(),
        );
      },
    );

    test('ProviderException (5xx) → Left(ProviderFailure)', () async {
      when(
        () => datasource.suggest(
          query: any(named: 'query'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenThrow(const ProviderException('Mapbox server error (HTTP 503)'));

      final result = await repo.suggest(query: 'test', sessionToken: 'token-1');

      expect(result.isLeft(), isTrue);
      expect(
        (result as Left<Failure, List<PlaceSuggestion>>).value,
        isA<ProviderFailure>(),
      );
    });

    test(
      'ProviderException (malformed response) → Left(ProviderFailure)',
      () async {
        when(
          () => datasource.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenThrow(
          const ProviderException(
            'Malformed Mapbox /suggest response: TypeError',
          ),
        );

        final result = await repo.suggest(
          query: 'test',
          sessionToken: 'token-1',
        );

        expect(result.isLeft(), isTrue);
        expect(
          (result as Left<Failure, List<PlaceSuggestion>>).value,
          isA<ProviderFailure>(),
        );
      },
    );

    test('DioException (network-level) → Left(NetworkFailure)', () async {
      when(
        () => datasource.suggest(
          query: any(named: 'query'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenThrow(_networkDioException());

      final result = await repo.suggest(query: 'test', sessionToken: 'token-1');

      expect(result.isLeft(), isTrue);
      expect(
        (result as Left<Failure, List<PlaceSuggestion>>).value,
        isA<NetworkFailure>(),
      );
    });

    test(
      'unexpected Exception → Left(ProviderFailure) (defensive catch)',
      () async {
        when(
          () => datasource.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenThrow(Exception('Something completely unexpected'));

        final result = await repo.suggest(
          query: 'test',
          sessionToken: 'token-1',
        );

        expect(result.isLeft(), isTrue);
        expect(
          (result as Left<Failure, List<PlaceSuggestion>>).value,
          isA<ProviderFailure>(),
        );
      },
    );
  });

  // =========================================================================
  // retrieve
  // =========================================================================
  group('retrieve — success', () {
    test('datasource returns model → Right(PlaceDetails)', () async {
      when(
        () => datasource.retrieve(
          mapboxId: any(named: 'mapboxId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenAnswer((_) async => _stubDetailsModel);

      final result = await repo.retrieve(
        providerPlaceId: 'place.abc',
        sessionToken: 'token-1',
      );

      expect(result.isRight(), isTrue);
      final details = (result as Right<Failure, PlaceDetails>).value;
      expect(details.providerPlaceId, 'place.abc');
      expect(details.latitude, 1.28);
      expect(details.longitude, 103.85);
    });
  });

  group('retrieve — failure mapping', () {
    test(
      'QuotaExhaustedException (429) → Left(QuotaExhaustedFailure)',
      () async {
        when(
          () => datasource.retrieve(
            mapboxId: any(named: 'mapboxId'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenThrow(
          const QuotaExhaustedException(
            'Mapbox rate limit exceeded (HTTP 429)',
          ),
        );

        final result = await repo.retrieve(
          providerPlaceId: 'place.abc',
          sessionToken: 'token-1',
        );

        expect(result.isLeft(), isTrue);
        expect(
          (result as Left<Failure, PlaceDetails>).value,
          isA<QuotaExhaustedFailure>(),
        );
      },
    );

    test(
      'QuotaExhaustedException (403 + billing body) → Left(QuotaExhaustedFailure)',
      () async {
        when(
          () => datasource.retrieve(
            mapboxId: any(named: 'mapboxId'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenThrow(
          const QuotaExhaustedException('Mapbox quota exhausted (HTTP 403)'),
        );

        final result = await repo.retrieve(
          providerPlaceId: 'place.abc',
          sessionToken: 'token-1',
        );

        expect(result.isLeft(), isTrue);
        expect(
          (result as Left<Failure, PlaceDetails>).value,
          isA<QuotaExhaustedFailure>(),
        );
      },
    );

    test('ProviderException (5xx) → Left(ProviderFailure)', () async {
      when(
        () => datasource.retrieve(
          mapboxId: any(named: 'mapboxId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenThrow(const ProviderException('Mapbox server error (HTTP 500)'));

      final result = await repo.retrieve(
        providerPlaceId: 'place.abc',
        sessionToken: 'token-1',
      );

      expect(result.isLeft(), isTrue);
      expect(
        (result as Left<Failure, PlaceDetails>).value,
        isA<ProviderFailure>(),
      );
    });

    test('ProviderException (malformed) → Left(ProviderFailure)', () async {
      when(
        () => datasource.retrieve(
          mapboxId: any(named: 'mapboxId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenThrow(
        const ProviderException(
          'Malformed Mapbox /retrieve response: TypeError',
        ),
      );

      final result = await repo.retrieve(
        providerPlaceId: 'place.abc',
        sessionToken: 'token-1',
      );

      expect(result.isLeft(), isTrue);
      expect(
        (result as Left<Failure, PlaceDetails>).value,
        isA<ProviderFailure>(),
      );
    });

    test('DioException (network-level) → Left(NetworkFailure)', () async {
      when(
        () => datasource.retrieve(
          mapboxId: any(named: 'mapboxId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenThrow(_networkDioException());

      final result = await repo.retrieve(
        providerPlaceId: 'place.abc',
        sessionToken: 'token-1',
      );

      expect(result.isLeft(), isTrue);
      expect(
        (result as Left<Failure, PlaceDetails>).value,
        isA<NetworkFailure>(),
      );
    });

    test(
      'unexpected Exception → Left(ProviderFailure) (defensive catch)',
      () async {
        when(
          () => datasource.retrieve(
            mapboxId: any(named: 'mapboxId'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenThrow(Exception('Something completely unexpected'));

        final result = await repo.retrieve(
          providerPlaceId: 'place.abc',
          sessionToken: 'token-1',
        );

        expect(result.isLeft(), isTrue);
        expect(
          (result as Left<Failure, PlaceDetails>).value,
          isA<ProviderFailure>(),
        );
      },
    );
  });
}
