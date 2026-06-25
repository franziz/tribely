import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/event.dart';
import '../entities/event_category.dart';
import '../entities/event_draft.dart';

// ---------------------------------------------------------------------------
// Params
// ---------------------------------------------------------------------------

/// Domain-side params for creating an event. Required fields are non-nullable —
/// the form gates progression to submit until each step is complete.
/// Maps to the server's POST /events request body via the data layer.
class CreateEventParams extends Equatable {
  const CreateEventParams({
    required this.title,
    required this.category,
    required this.venueName,
    required this.venueCategory,
    required this.latitude,
    required this.longitude,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.approvalMode,
    required this.description,
    this.costNotes,
  });

  final String title;
  final EventCategory category;

  /// Maps to server `venue.address`. City is resolved by the data layer
  /// (hardcoded to 'Singapore' for MVP; extended when multi-city lands).
  final String venueName;

  /// Raw snake_case venue category string (see [VenueCategory]).
  /// Maps to server `venue.category`.
  final String venueCategory;

  final double latitude;
  final double longitude;
  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;

  /// 'auto' | 'manual'
  final String approvalMode;
  final String description;

  /// Optional host-authored free-text cost note. Omitted from the POST body
  /// when null or empty (server schema is `.optional()`). Never structured —
  /// CEO guardrail: plain String only, no numeric/split-type primitives.
  final String? costNotes;

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
    approvalMode,
    description,
    costNotes,
  ];
}

// ---------------------------------------------------------------------------
// Repository interface
// ---------------------------------------------------------------------------

/// Abstract repository for the events feature.
/// Implementations live in data/repositories/; see auth_repository.dart for
/// the canonical shape.
abstract class EventRepository {
  /// Create an event on the server. Returns the newly-created [Event] on
  /// success. The data layer hardcodes city='Singapore' for the v1 MVP;
  /// [CreateEventParams.costNotes] is forwarded when present.
  Future<Either<Failure, Event>> createEvent(CreateEventParams params);

  /// Load a locally-persisted draft. Returns [null] when no draft exists.
  Future<Either<Failure, EventDraft?>> loadDraft();

  /// Persist [draft] locally (e.g., shared_preferences or local DB).
  /// Overwrites any existing draft.
  Future<Either<Failure, void>> saveDraft(EventDraft draft);

  /// Remove the locally-persisted draft. Idempotent — succeeds if no draft
  /// exists.
  Future<Either<Failure, void>> clearDraft();

  /// Cancel a published event on the server.
  ///
  /// Only the host may cancel. The server returns 204 No Content on success.
  /// Returns [Right(null)] on success, or a typed [Failure] on error.
  Future<Either<Failure, void>> cancelEvent(String eventId);
}
