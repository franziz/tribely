import 'package:equatable/equatable.dart';

import '../../domain/entities/event.dart';
import '../../domain/entities/event_category.dart';

/// JSON model mirroring the server's EventResponse shape PLUS a flattened
/// [hostDisplayName] projection synthesised by the datasource layer from the
/// [eventWithHostResponseSchema] wrapper (`{ event: {...}, host: { displayName } }`).
///
/// This model is no longer a 1:1 mirror of eventResponseSchema — it also carries
/// the [hostDisplayName] pulled from the wrapper's `host` sibling. The datasource
/// synthesises this via a spread so [fromJson] remains a single-map parse.
///
/// See apps/api/src/features/events/presentation/http/schemas/event.schemas.ts
/// (eventResponseSchema + eventWithHostResponseSchema) and the controller's
/// toEventResponse() serialiser for the canonical server field list.
///
/// Fields not present in the domain [Event] entity (cancellationReason,
/// updatedAt) are parsed defensively but discarded — the domain has no use
/// for them in v1. Add them to [Event] when a feature needs them.
/// host.avatarUrl + goingCount remain deferred to TRI-19.
class EventModel extends Equatable {
  const EventModel({
    required this.id,
    required this.hostUserId,
    required this.title,
    required this.description,
    required this.venue,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.category,
    required this.costSplit,
    required this.approvalMode,
    required this.status,
    required this.createdAt,
    this.hostDisplayName,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final venueJson = json['venue'] as Map<String, dynamic>;
    return EventModel(
      id: json['id'] as String,
      hostUserId: json['hostUserId'] as String,
      title: json['title'] as String,
      // description is nullable on the wire (server allows null)
      description: json['description'] as String?,
      venue: EventVenueModel.fromJson(venueJson),
      // .toLocal() converts the server's UTC timestamp to the device's local
      // timezone so display widgets render the correct local time. The domain
      // Entity stores local DateTimes; the wire always carries UTC (trailing Z).
      startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
      endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
      capacity: (json['capacity'] as num).toInt(),
      category: EventCategory.fromWire(json['category'] as String),
      costSplit: json['costSplit'] as String,
      approvalMode: json['approvalMode'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      hostDisplayName: json['hostDisplayName'] as String?,
    );
  }

  final String id;
  final String hostUserId;
  final String title;
  final String? description;
  final EventVenueModel venue;
  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;
  final EventCategory category;
  final String costSplit;
  final String approvalMode;
  final String status;
  final DateTime createdAt;

  /// Projected from the [eventWithHostResponseSchema] wrapper's `host.displayName`
  /// field by the datasource. Nullable — server contract says non-null, but the
  /// datasource applies a defensive null-safe cast so absent/null gracefully
  /// flows through as null rather than throwing. host.avatarUrl + goingCount
  /// deferred to TRI-19.
  final String? hostDisplayName;

  /// Map to the domain [Event] entity. The domain field is named [hostId];
  /// the server wire field is [hostUserId] — translation lives here.
  Event toEntity() => Event(
    id: id,
    hostId: hostUserId,
    title: title,
    description: description,
    venue: venue.toEntity(),
    startsAt: startsAt,
    endsAt: endsAt,
    capacity: capacity,
    category: category,
    costSplit: costSplit,
    approvalMode: approvalMode,
    status: status,
    createdAt: createdAt,
    hostDisplayName: hostDisplayName,
  );

  @override
  List<Object?> get props => [
    id,
    hostUserId,
    title,
    description,
    venue,
    startsAt,
    endsAt,
    capacity,
    category,
    costSplit,
    approvalMode,
    status,
    createdAt,
    hostDisplayName,
  ];
}

/// JSON model for the venue sub-object embedded in [EventModel].
class EventVenueModel extends Equatable {
  const EventVenueModel({
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.category,
  });

  factory EventVenueModel.fromJson(Map<String, dynamic> json) {
    return EventVenueModel(
      address: json['address'] as String,
      city: json['city'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      // category is non-nullable on the wire (server enforces it on all events
      // after TRI-33). Defensive fallback to empty string if server sends null.
      category: (json['category'] as String?) ?? '',
    );
  }

  final String address;
  final String city;
  final double latitude;
  final double longitude;

  /// Raw snake_case venue category string matching the server enum.
  /// See [VenueCategory] for the full closed set and public/private helpers.
  final String category;

  EventVenue toEntity() => EventVenue(
    address: address,
    city: city,
    latitude: latitude,
    longitude: longitude,
    category: category,
  );

  @override
  List<Object?> get props => [address, city, latitude, longitude, category];
}
