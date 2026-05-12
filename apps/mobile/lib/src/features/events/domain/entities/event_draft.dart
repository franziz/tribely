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
  });

  final String? title;
  final EventCategory? category;

  /// Human-readable venue label. Maps to server `venue.address` on submit.
  final String? venueName;
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

  EventDraft copyWith({
    String? title,
    EventCategory? category,
    String? venueName,
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
  }) => EventDraft(
    title: title ?? this.title,
    category: category ?? this.category,
    venueName: venueName ?? this.venueName,
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
  );

  @override
  List<Object?> get props => [
    title,
    category,
    venueName,
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
  ];
}
