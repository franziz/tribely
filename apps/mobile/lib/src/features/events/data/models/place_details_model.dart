import '../../domain/entities/place_details.dart';

/// Wire-shape model for the Mapbox `/retrieve` response `features[0]` GeoJSON
/// Feature object.
///
/// IMPORTANT — GeoJSON coordinate order:
///   `geometry.coordinates` is `[longitude, latitude]` (GeoJSON spec, Mapbox
///   convention). This is the OPPOSITE of the lat/lng order used in most
///   non-GeoJSON APIs. [fromJson] explicitly maps index 0 → longitude and
///   index 1 → latitude. Any change here breaks the regression guard in
///   `place_details_model_test.dart` — do NOT swap the indices.
///
/// Mapbox reference fields (from `/retrieve` properties):
///   - `properties.mapbox_id`      — opaque place ID
///   - `properties.name`           — short human-readable name
///   - `properties.full_address`   — full formatted address (retrieve uses
///                                   `full_address`; suggest uses
///                                   `place_formatted`)
///   - `geometry.coordinates`      — [longitude, latitude] (GeoJSON order)
///   - `properties.poi_category`   — array of category strings (nullable)
class PlaceDetailsModel {
  const PlaceDetailsModel({
    required this.mapboxId,
    required this.name,
    required this.formattedAddress,
    required this.longitude,
    required this.latitude,
    this.rawCategory,
  });

  factory PlaceDetailsModel.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'] as Map<String, dynamic>;
    final geometry = json['geometry'] as Map<String, dynamic>;

    // GeoJSON: coordinates[0] = longitude, coordinates[1] = latitude.
    // This is counter-intuitive — the regression test in
    // place_details_model_test.dart guards against accidental swaps.
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final longitude = (coordinates[0] as num).toDouble();
    final latitude = (coordinates[1] as num).toDouble();

    // `full_address` is the canonical field for /retrieve responses.
    // Fall back to `place_formatted` defensively for older API versions.
    final formattedAddress =
        (properties['full_address'] as String?) ??
        (properties['place_formatted'] as String?) ??
        '';

    // poi_category may be absent or an empty array — treat both as null.
    final categories = properties['poi_category'];
    final String? rawCategory;
    if (categories is List && categories.isNotEmpty) {
      rawCategory = categories.first as String?;
    } else {
      rawCategory = null;
    }

    return PlaceDetailsModel(
      mapboxId: properties['mapbox_id'] as String,
      name: properties['name'] as String,
      formattedAddress: formattedAddress,
      longitude: longitude,
      latitude: latitude,
      rawCategory: rawCategory,
    );
  }

  final String mapboxId;
  final String name;
  final String formattedAddress;

  /// Longitude from `geometry.coordinates[0]`. GeoJSON lng-first order.
  final double longitude;

  /// Latitude from `geometry.coordinates[1]`. GeoJSON lng-first order.
  final double latitude;

  final String? rawCategory;

  PlaceDetails toEntity() => PlaceDetails(
    providerPlaceId: mapboxId,
    name: name,
    formattedAddress: formattedAddress,
    latitude: latitude,
    longitude: longitude,
    rawCategory: rawCategory,
  );
}
