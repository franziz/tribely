import '../../domain/entities/event_category.dart';
import '../../domain/repositories/event_repository.dart';

/// Converts a domain [CreateEventParams] into the JSON body for POST /events.
///
/// Wire shape matches apps/api/src/features/events/presentation/http/schemas/
/// event.schemas.ts (createEventBodySchema).
class CreateEventParamsModel {
  const CreateEventParamsModel({
    required this.title,
    required this.description,
    required this.venueAddress,
    required this.venueCategory,
    required this.latitude,
    required this.longitude,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.category,
    required this.approvalMode,
    this.costNotes,
    this.coverPhotoStorageKey,
  });

  factory CreateEventParamsModel.fromDomain(CreateEventParams params) {
    return CreateEventParamsModel(
      title: params.title.trim(),
      description: params.description.trim(),
      venueAddress: params.venueName.trim(),
      venueCategory: params.venueCategory,
      latitude: params.latitude,
      longitude: params.longitude,
      startsAt: params.startsAt,
      endsAt: params.endsAt,
      capacity: params.capacity,
      category: params.category,
      approvalMode: params.approvalMode,
      costNotes: params.costNotes,
      coverPhotoStorageKey: params.coverPhotoStorageKey,
    );
  }

  final String title;
  final String description;
  final String venueAddress;

  /// Raw snake_case venue category string (see [VenueCategory]).
  /// Serialised as `venue.category` in the POST body.
  final String venueCategory;

  final double latitude;
  final double longitude;
  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;
  final EventCategory category;
  final String approvalMode;

  /// Optional host-authored free-text cost note. Omitted from the POST body
  /// when null or empty — the server schema is `.optional()`, so key-absence
  /// is the correct forward-compatible form. CEO guardrail: plain String only.
  final String? costNotes;

  /// Storage key (object path) for the uploaded cover photo. Omitted from the
  /// POST body when null — the server schema is `.optional()`.
  final String? coverPhotoStorageKey;

  Map<String, dynamic> toJson() {
    // Hardcoded for Singapore-first launch (per CLAUDE.md). When TRI-23 ships
    // the map picker, derive city via reverse geocode from lat/lng.
    const venueCity = 'Singapore';

    return {
      'title': title,
      'description': description,
      'venue': {
        'address': venueAddress,
        'city': venueCity,
        'latitude': latitude,
        'longitude': longitude,
        'category': venueCategory,
      },
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
      'capacity': capacity,
      'category': category.wireValue,
      'approvalMode': approvalMode,
      if (costNotes != null && costNotes!.isNotEmpty) 'costNotes': costNotes,
      if (coverPhotoStorageKey != null)
        'coverPhotoStorageKey': coverPhotoStorageKey,
    };
  }
}
