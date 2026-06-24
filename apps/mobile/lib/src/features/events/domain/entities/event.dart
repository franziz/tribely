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
    required this.approvalMode,
    required this.status,
    required this.createdAt,
    required this.hostIsVerified,
    this.costNotes,
    this.hostDisplayName,
    this.coverPhotoUrl,
  });

  final String id;
  final String hostId;
  final String title;
  final String? description;

  /// True iff host satisfies TRI-86's active verification signal set. Always
  /// present (non-nullable). At launch, every host is `false` until upstream
  /// signals ship — see docs/specs/user-is-verified-projection.md.
  final bool hostIsVerified;

  /// Display name of the host, projected from the eventWithHostResponseSchema
  /// wrapper by the data layer. Nullable — graceful fallback to 'Host' in the
  /// UI when absent. Avatar + profile nav deferred to TRI-19.
  final String? hostDisplayName;

  /// URL of the event's cover photo, as returned by the server (TRI-49).
  /// Nullable — absent when the host has not uploaded a cover photo.
  final String? coverPhotoUrl;

  /// Venue is kept as a nested value. The data layer maps the server's venue
  /// object into this [EventVenue] struct.
  final EventVenue venue;

  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;
  final EventCategory category;

  /// Optional host-authored free-text cost note (e.g. "Pay your own way").
  /// Nullable — absent when the host left the field blank. Wire value:
  /// `z.string().nullable()` per the server schema. CEO guardrail: plain
  /// String only, never a structured/numeric cost primitive.
  final String? costNotes;

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
    String? costNotes,
    String? approvalMode,
    String? status,
    DateTime? createdAt,
    bool? hostIsVerified,
    String? hostDisplayName,
    String? coverPhotoUrl,
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
    costNotes: costNotes ?? this.costNotes,
    approvalMode: approvalMode ?? this.approvalMode,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    hostIsVerified: hostIsVerified ?? this.hostIsVerified,
    hostDisplayName: hostDisplayName ?? this.hostDisplayName,
    coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
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
    costNotes,
    approvalMode,
    status,
    createdAt,
    hostIsVerified,
    hostDisplayName,
    coverPhotoUrl,
  ];
}

/// Venue sub-value embedded in [Event]. Mirrors the server's Venue value
/// object shape (address, city, lat, lng, category).
class EventVenue extends Equatable {
  const EventVenue({
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.category,
  });

  final String address;
  final String city;
  final double latitude;
  final double longitude;

  /// Raw snake_case venue category string. See [VenueCategory] for helpers.
  final String category;

  @override
  List<Object?> get props => [address, city, latitude, longitude, category];
}
