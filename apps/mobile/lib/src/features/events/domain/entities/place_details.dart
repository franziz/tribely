import 'package:equatable/equatable.dart';

/// Full place details returned by [PlaceSearchPort.retrieve].
///
/// Constructed from the provider's retrieve response and stored on
/// [EventDraft] after the user confirms a venue selection.
class PlaceDetails extends Equatable {
  const PlaceDetails({
    required this.providerPlaceId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.rawCategory,
  });

  /// Opaque Mapbox `mapbox_id`. Stored on draft as [EventDraft.providerPlaceId].
  final String providerPlaceId;

  /// Short human-readable place name, e.g. "Lau Pa Sat".
  final String name;

  /// Full formatted address, e.g. "18 Raffles Quay, Singapore 048582".
  /// Stored on draft as [EventDraft.venueAddress].
  final String formattedAddress;

  final double latitude;
  final double longitude;

  /// Raw Mapbox `poi_category[0]`, or null when the provider omits it.
  /// Stored on draft as [EventDraft.rawProviderCategory] BEFORE mapping.
  final String? rawCategory;

  @override
  List<Object?> get props => [
    providerPlaceId,
    name,
    formattedAddress,
    latitude,
    longitude,
    rawCategory,
  ];
}
