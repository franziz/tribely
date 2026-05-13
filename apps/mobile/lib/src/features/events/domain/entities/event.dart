import 'package:equatable/equatable.dart';

import 'event_category.dart';

/// Domain entity representing a hydrated event as returned by the server.
/// Pure Dart — no JSON parsing (that lives in data/models/event_model.dart).
class Event extends Equatable {
  const Event({
    required this.id,
    required this.hostId,
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

  final String id;
  final String hostId;
  final String title;
  final String? description;

  /// Display name of the host, projected from the eventWithHostResponseSchema
  /// wrapper by the data layer. Nullable — graceful fallback to 'Host' in the
  /// UI when absent. Avatar + profile nav deferred to TRI-19.
  final String? hostDisplayName;

  /// Venue is kept as a nested value. The data layer maps the server's venue
  /// object into this [EventVenue] struct.
  final EventVenue venue;

  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;
  final EventCategory category;

  /// Wire value: 'own' | 'host_paid' | 'split'. Not surfaced to the create-
  /// event UI in v1 — the data layer hardcodes 'own' on create.
  final String costSplit;

  /// Wire value: 'auto' | 'manual'.
  final String approvalMode;

  /// Wire value: 'draft' | 'published' | 'cancelled' | 'completed'.
  final String status;

  final DateTime createdAt;

  Event copyWith({
    String? id,
    String? hostId,
    String? title,
    String? description,
    EventVenue? venue,
    DateTime? startsAt,
    DateTime? endsAt,
    int? capacity,
    EventCategory? category,
    String? costSplit,
    String? approvalMode,
    String? status,
    DateTime? createdAt,
    String? hostDisplayName,
  }) => Event(
    id: id ?? this.id,
    hostId: hostId ?? this.hostId,
    title: title ?? this.title,
    description: description ?? this.description,
    venue: venue ?? this.venue,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    capacity: capacity ?? this.capacity,
    category: category ?? this.category,
    costSplit: costSplit ?? this.costSplit,
    approvalMode: approvalMode ?? this.approvalMode,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    hostDisplayName: hostDisplayName ?? this.hostDisplayName,
  );

  @override
  List<Object?> get props => [
    id,
    hostId,
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

/// Venue sub-value embedded in [Event]. Mirrors the server's Venue value
/// object shape (address, city, lat, lng).
class EventVenue extends Equatable {
  const EventVenue({
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final String city;
  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [address, city, latitude, longitude];
}
