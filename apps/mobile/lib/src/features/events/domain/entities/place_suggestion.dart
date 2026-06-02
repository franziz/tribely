import 'package:equatable/equatable.dart';

/// A single autocomplete suggestion returned by [PlaceSearchPort.suggest].
///
/// [providerPlaceId] is the opaque Mapbox `mapbox_id` — pass it back to
/// [PlaceSearchPort.retrieve] using the SAME session token to fetch full
/// details. The UI should treat this as an opaque handle and never parse it.
class PlaceSuggestion extends Equatable {
  const PlaceSuggestion({
    required this.providerPlaceId,
    required this.name,
    required this.placeFormatted,
    this.rawCategory,
  });

  /// Opaque Mapbox `mapbox_id`. Pass to [PlaceSearchPort.retrieve].
  final String providerPlaceId;

  /// Short human-readable place name, e.g. "Lau Pa Sat".
  final String name;

  /// Full formatted address, e.g. "18 Raffles Quay, Singapore 048582".
  final String placeFormatted;

  /// Raw Mapbox `poi_category[0]`, or null when the provider omits it.
  /// Feed through [mapProviderCategoryToVenueCategory] before storing on a
  /// draft or sending to the API.
  final String? rawCategory;

  @override
  List<Object?> get props => [providerPlaceId, name, placeFormatted, rawCategory];
}
