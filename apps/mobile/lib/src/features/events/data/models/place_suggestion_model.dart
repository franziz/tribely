import '../../domain/entities/place_suggestion.dart';

/// Wire-shape model for a single item in the Mapbox `/suggest` response
/// `suggestions[]` array.
///
/// Mapbox reference fields:
///   - `name`            — short human-readable name
///   - `mapbox_id`       — opaque place ID; pass to `/retrieve`
///   - `place_formatted` — full formatted address
///   - `poi_category`    — array of category strings; we use index 0 (nullable)
class PlaceSuggestionModel {
  const PlaceSuggestionModel({
    required this.mapboxId,
    required this.name,
    required this.placeFormatted,
    this.rawCategory,
  });

  factory PlaceSuggestionModel.fromJson(Map<String, dynamic> json) {
    // poi_category may be absent or an empty array — treat both as null.
    final categories = json['poi_category'];
    final String? rawCategory;
    if (categories is List && categories.isNotEmpty) {
      rawCategory = categories.first as String?;
    } else {
      rawCategory = null;
    }

    return PlaceSuggestionModel(
      mapboxId: json['mapbox_id'] as String,
      name: json['name'] as String,
      placeFormatted: (json['place_formatted'] as String?) ?? '',
      rawCategory: rawCategory,
    );
  }

  final String mapboxId;
  final String name;
  final String placeFormatted;
  final String? rawCategory;

  PlaceSuggestion toEntity() => PlaceSuggestion(
    providerPlaceId: mapboxId,
    name: name,
    placeFormatted: placeFormatted,
    rawCategory: rawCategory,
  );
}
