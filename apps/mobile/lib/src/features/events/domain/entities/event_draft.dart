import 'package:equatable/equatable.dart';

import 'event_category.dart';

/// In-progress form state for the multi-step create-event flow.
/// All editable fields are nullable to model the partially-filled state while
/// the user advances through steps. This is a pure DTO — no methods beyond
/// [copyWith] and equality.
class EventDraft extends Equatable {
  const EventDraft({
    this.title,
    this.category,
    this.venueName,
    this.venueCategory,
    this.latitude,
    this.longitude,
    this.startsAt,
    this.endsAt,
    this.capacity,
    // costNotes is kept for forward-compat even though Brief 6 / Step 4 will
    // not surface it in v1. Storing it in the draft avoids a schema migration
    // when the cost-split UI is added in a future ticket.
    this.costNotes,
    // Tribely's trust posture is vet-before-meet; manual is the safer default
    // so the user is always in control of who joins their event.
    this.approvalMode = 'manual',
    this.description,
    this.currentStep = 0,
    this.lastUpdatedAt,
    this.providerPlaceId,
    this.venueAddress,
    this.rawProviderCategory,
    this.venueDisplayNameOverride,
  });

  final String? title;
  final EventCategory? category;

  /// Human-readable venue label. Maps to server `venue.address` on submit.
  final String? venueName;

  /// Raw snake_case venue category string (see [VenueCategory]).
  /// Maps to server `venue.category` on submit. Set by Step 2 (venue picker)
  /// when the user selects a venue category. Nullable until the user selects.
  final String? venueCategory;

  final double? latitude;
  final double? longitude;

  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? capacity;

  /// Forward-compat: stored in draft but NOT submitted in v1 create flow.
  /// The data layer hardcodes costSplit='own'; this field is reserved for the
  /// future cost-split UI (see Brief 6 TODO).
  final String? costNotes;

  /// 'auto' | 'manual'
  final String? approvalMode;
  final String? description;

  /// Zero-based index of the step the user was last on.
  final int currentStep;

  final DateTime? lastUpdatedAt;

  /// Opaque Mapbox `mapbox_id` for the selected place. Passed back to
  /// [PlaceSearchPort.retrieve] if the user re-opens the venue picker.
  final String? providerPlaceId;

  /// Formatted address from the place provider (e.g. "18 Raffles Quay,
  /// Singapore 048582"). Maps to server `venue.address` on submit (alongside
  /// the existing [venueName] which carries the short name).
  final String? venueAddress;

  /// Raw Mapbox `poi_category[0]` BEFORE mapping through
  /// [mapProviderCategoryToVenueCategory]. Stored so the mapper can be
  /// re-run if the mapping table changes, without re-fetching from the API.
  final String? rawProviderCategory;

  /// Optional free-text display label that overrides [venueName] in the UI.
  /// Populated when the user manually edits the venue name after picker
  /// selection. Does NOT affect [venueName] used for API submission.
  final String? venueDisplayNameOverride;

  EventDraft copyWith({
    String? title,
    EventCategory? category,
    String? venueName,
    String? venueCategory,
    double? latitude,
    double? longitude,
    DateTime? startsAt,
    DateTime? endsAt,
    int? capacity,
    String? costNotes,
    String? approvalMode,
    String? description,
    int? currentStep,
    DateTime? lastUpdatedAt,
    String? providerPlaceId,
    String? venueAddress,
    String? rawProviderCategory,
    String? venueDisplayNameOverride,
  }) => EventDraft(
    title: title ?? this.title,
    category: category ?? this.category,
    venueName: venueName ?? this.venueName,
    venueCategory: venueCategory ?? this.venueCategory,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    capacity: capacity ?? this.capacity,
    costNotes: costNotes ?? this.costNotes,
    approvalMode: approvalMode ?? this.approvalMode,
    description: description ?? this.description,
    currentStep: currentStep ?? this.currentStep,
    lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    providerPlaceId: providerPlaceId ?? this.providerPlaceId,
    venueAddress: venueAddress ?? this.venueAddress,
    rawProviderCategory: rawProviderCategory ?? this.rawProviderCategory,
    venueDisplayNameOverride:
        venueDisplayNameOverride ?? this.venueDisplayNameOverride,
  );

  @override
  List<Object?> get props => [
    title,
    category,
    venueName,
    venueCategory,
    latitude,
    longitude,
    startsAt,
    endsAt,
    capacity,
    costNotes,
    approvalMode,
    description,
    currentStep,
    lastUpdatedAt,
    providerPlaceId,
    venueAddress,
    rawProviderCategory,
    venueDisplayNameOverride,
  ];
}
