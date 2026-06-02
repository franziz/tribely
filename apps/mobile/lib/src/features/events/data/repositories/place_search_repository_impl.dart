import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/place_details.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/ports/place_search_port.dart';
import '../datasources/mapbox_place_search_remote_datasource.dart';
import '../exceptions/place_search_exceptions.dart';

/// Concrete implementation of [PlaceSearchPort] backed by
/// [MapboxPlaceSearchRemoteDatasource].
///
/// Error mapping:
///   [QuotaExhaustedException] → [QuotaExhaustedFailure]
///   [ProviderException]       → [ProviderFailure]
///   [DioException]            → [NetworkFailure]
///   anything else             → [ProviderFailure] (defensive)
class PlaceSearchRepositoryImpl implements PlaceSearchPort {
  const PlaceSearchRepositoryImpl({
    required MapboxPlaceSearchRemoteDatasource datasource,
  }) : _datasource = datasource;

  final MapboxPlaceSearchRemoteDatasource _datasource;

  @override
  Future<Either<Failure, List<PlaceSuggestion>>> suggest({
    required String query,
    required String sessionToken,
  }) async {
    try {
      final models = await _datasource.suggest(
        query: query,
        sessionToken: sessionToken,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on QuotaExhaustedException catch (e) {
      return Left(QuotaExhaustedFailure(e.message));
    } on ProviderException catch (e) {
      return Left(ProviderFailure(e.message));
    } on DioException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(ProviderFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, PlaceDetails>> retrieve({
    required String providerPlaceId,
    required String sessionToken,
  }) async {
    try {
      final model = await _datasource.retrieve(
        mapboxId: providerPlaceId,
        sessionToken: sessionToken,
      );
      return Right(model.toEntity());
    } on QuotaExhaustedException catch (e) {
      return Left(QuotaExhaustedFailure(e.message));
    } on ProviderException catch (e) {
      return Left(ProviderFailure(e.message));
    } on DioException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(ProviderFailure('Unexpected error: $e'));
    }
  }
}
