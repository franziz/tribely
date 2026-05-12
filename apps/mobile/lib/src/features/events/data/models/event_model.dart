import 'package:equatable/equatable.dart';

import '../../domain/entities/event.dart';
import '../../domain/entities/event_category.dart';

/// JSON model mirroring the server's EventResponse shape.
/// See apps/api/src/features/events/presentation/http/schemas/event.schemas.ts
/// (eventResponseSchema) and the controller's toEventResponse() serializer for
/// the canonical field list.
///
/// Fields not present in the domain [Event] entity (cancellationReason,
/// updatedAt) are parsed defensively but discarded — the domain has no use
/// for them in v1. Add them to [Event] when a feature needs them.
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
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      capacity: (json['capacity'] as num).toInt(),
      category: EventCategory.fromWire(json['category'] as String),
      costSplit: json['costSplit'] as String,
      approvalMode: json['approvalMode'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
  ];
}

/// JSON model for the venue sub-object embedded in [EventModel].
class EventVenueModel extends Equatable {
  const EventVenueModel({
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  factory EventVenueModel.fromJson(Map<String, dynamic> json) {
    return EventVenueModel(
      address: json['address'] as String,
      city: json['city'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  final String address;
  final String city;
  final double latitude;
  final double longitude;

  EventVenue toEntity() => EventVenue(
    address: address,
    city: city,
    latitude: latitude,
    longitude: longitude,
  );

  @override
  List<Object?> get props => [address, city, latitude, longitude];
}
