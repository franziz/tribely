import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/place_details.dart';
import '../entities/place_suggestion.dart';

/// Port (driven-adapter boundary) for external place-search providers.
///
/// Implementations live in `data/datasources/` and are injected at the
/// service-locator layer — domain code only ever sees this interface.
abstract class PlaceSearchPort {
  /// Returns autocomplete suggestions for [query].
  ///
  /// [sessionToken] must be consistent across all [suggest] calls and the
  /// subsequent [retrieve] call in the same user session — Mapbox bills a
  /// suggest+retrieve pair as one session and a new token starts a new
  /// billable session.
  ///
  /// - Right([]) when the provider returns zero results (not an error).
  /// - Left([QuotaExhaustedFailure]) on HTTP 429 or 403-with-quota-body.
  /// - Left([NetworkFailure]) on connection failure.
  /// - Left([ProviderFailure]) on provider 5xx or malformed response.
  Future<Either<Failure, List<PlaceSuggestion>>> suggest({
    required String query,
    required String sessionToken,
  });

  /// Fetches full place details for [providerPlaceId].
  ///
  /// [sessionToken] MUST be the SAME token used for the preceding [suggest]
  /// call — Mapbox collapses the suggest+retrieve pair into one billable
  /// session only when the token matches.
  ///
  /// - Left([QuotaExhaustedFailure]) on HTTP 429 or 403-with-quota-body.
  /// - Left([NetworkFailure]) on connection failure.
  /// - Left([ProviderFailure]) on provider 5xx or malformed response.
  Future<Either<Failure, PlaceDetails>> retrieve({
    required String providerPlaceId,
    required String sessionToken,
  });
}
