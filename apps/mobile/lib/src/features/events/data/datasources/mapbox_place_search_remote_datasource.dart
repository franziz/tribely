import 'package:dio/dio.dart';

import '../../domain/constants/place_search_constants.dart';
import '../exceptions/place_search_exceptions.dart';
import '../models/place_details_model.dart';
import '../models/place_suggestion_model.dart';

/// Mapbox Searchbox API base URL. Isolated to make future provider-switching
/// easy — swap this constant + the two path suffixes without touching the impl.
const String _kMapboxSearchBaseUrl =
    'https://api.mapbox.com/search/searchbox/v1';

/// Compile-time Mapbox public access token.
///
/// Set via `--dart-define=MAPBOX_ACCESS_TOKEN=pk.xxx` (identical mechanism to
/// `API_BASE_URL` in [AppConfig]).
const String _kMapboxAccessToken = String.fromEnvironment(
  'MAPBOX_ACCESS_TOKEN',
);

/// Interface for the Mapbox place-search remote data source.
///
/// Throws [QuotaExhaustedException] or [ProviderException] on Mapbox errors.
/// [DioException] for network-level failures is let through to bubble up to
/// [PlaceSearchRepositoryImpl], which maps it to [NetworkFailure].
abstract class MapboxPlaceSearchRemoteDatasource {
  /// Returns a list of [PlaceSuggestionModel] for [query].
  ///
  /// Throws [QuotaExhaustedException] on HTTP 429 / 403-with-quota.
  /// Throws [ProviderException] on HTTP 5xx or malformed response.
  Future<List<PlaceSuggestionModel>> suggest({
    required String query,
    required String sessionToken,
  });

  /// Returns a [PlaceDetailsModel] for [mapboxId].
  ///
  /// Throws [QuotaExhaustedException] on HTTP 429 / 403-with-quota.
  /// Throws [ProviderException] on HTTP 5xx or malformed response.
  Future<PlaceDetailsModel> retrieve({
    required String mapboxId,
    required String sessionToken,
  });
}

class MapboxPlaceSearchRemoteDatasourceImpl
    implements MapboxPlaceSearchRemoteDatasource {
  MapboxPlaceSearchRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<PlaceSuggestionModel>> suggest({
    required String query,
    required String sessionToken,
  }) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(
        '$_kMapboxSearchBaseUrl/suggest',
        queryParameters: {
          'q': query,
          'session_token': sessionToken,
          'access_token': _kMapboxAccessToken,
          'country': kSgCountryCode,
          'language': kSearchLanguage,
          'proximity': kSgProximityLngLat,
          'limit': kSearchLimit,
          'types': kSearchTypes,
        },
      );
    } on DioException catch (e) {
      throw _mapDioExceptionToDataLayerException(e);
    }

    try {
      final data = response.data!;
      final suggestions = data['suggestions'] as List<dynamic>;
      return suggestions
          .cast<Map<String, dynamic>>()
          .map(PlaceSuggestionModel.fromJson)
          .toList();
    } catch (e) {
      throw ProviderException('Malformed Mapbox /suggest response: $e');
    }
  }

  @override
  Future<PlaceDetailsModel> retrieve({
    required String mapboxId,
    required String sessionToken,
  }) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(
        '$_kMapboxSearchBaseUrl/retrieve/$mapboxId',
        queryParameters: {
          'session_token': sessionToken,
          'access_token': _kMapboxAccessToken,
        },
      );
    } on DioException catch (e) {
      throw _mapDioExceptionToDataLayerException(e);
    }

    try {
      final data = response.data!;
      final features = data['features'] as List<dynamic>;
      final feature = features.first as Map<String, dynamic>;
      return PlaceDetailsModel.fromJson(feature);
    } catch (e) {
      throw ProviderException('Malformed Mapbox /retrieve response: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Maps a [DioException] to a data-layer exception when the error is a
  /// Mapbox-originated HTTP error (not a network-level failure).
  ///
  /// - HTTP 429 → [QuotaExhaustedException]
  /// - HTTP 403 with "quota" or "billing" in the body → [QuotaExhaustedException]
  /// - HTTP 5xx → [ProviderException]
  /// - Other HTTP errors → [ProviderException] (conservative)
  ///
  /// Network-level [DioException]s (no response) are returned as-is so the
  /// repository layer can map them to [NetworkFailure].
  ///
  /// Returns the exception — callers must `throw` the result explicitly.
  Exception _mapDioExceptionToDataLayerException(DioException e) {
    final response = e.response;
    if (response == null) {
      // Network-level failure — return unchanged so the repository maps it.
      return e;
    }

    final statusCode = response.statusCode ?? 0;

    if (statusCode == 429) {
      return const QuotaExhaustedException(
        'Mapbox rate limit exceeded (HTTP 429)',
      );
    }

    if (statusCode == 403) {
      final body = response.data?.toString() ?? '';
      if (body.contains('quota') || body.contains('billing')) {
        return const QuotaExhaustedException(
          'Mapbox quota exhausted (HTTP 403)',
        );
      }
      return const ProviderException('Mapbox returned HTTP 403');
    }

    if (statusCode >= 500) {
      return ProviderException('Mapbox server error (HTTP $statusCode)');
    }

    // Any other HTTP error (4xx not handled above) treated as provider error.
    return ProviderException('Mapbox returned HTTP $statusCode');
  }
}
