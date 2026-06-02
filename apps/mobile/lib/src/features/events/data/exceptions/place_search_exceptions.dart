// Data-layer exceptions for the Mapbox place-search integration.
//
// These are NOT domain types — they stay in `data/exceptions/` and are mapped
// to [Failure] subclasses by [PlaceSearchRepositoryImpl].

/// Thrown by [MapboxPlaceSearchRemoteDatasource] when Mapbox responds with
/// HTTP 429, or HTTP 403 with a response body containing "quota" or "billing".
///
/// The repository maps this to [QuotaExhaustedFailure].
class QuotaExhaustedException implements Exception {
  const QuotaExhaustedException(this.message);

  final String message;

  @override
  String toString() => 'QuotaExhaustedException: $message';
}

/// Thrown by [MapboxPlaceSearchRemoteDatasource] when Mapbox responds with a
/// 5xx status code, or when the response body is malformed or missing required
/// fields that prevent mapping to a domain entity.
///
/// The repository maps this to [ProviderFailure].
class ProviderException implements Exception {
  const ProviderException(this.message);

  final String message;

  @override
  String toString() => 'ProviderException: $message';
}
