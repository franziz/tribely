import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/event.dart';
import '../entities/event_category.dart';
import '../entities/event_draft.dart';

// ---------------------------------------------------------------------------
// Params
// ---------------------------------------------------------------------------

/// Domain-side params for creating an event. All fields are non-nullable —
/// the form gates progression to submit until each step is complete.
/// Maps to the server's POST /events request body via the data layer.
class CreateEventParams extends Equatable {
  const CreateEventParams({
    required this.title,
    required this.category,
    required this.venueName,
    required this.latitude,
    required this.longitude,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.approvalMode,
    required this.description,
  });

  final String title;
  final EventCategory category;

  /// Maps to server `venue.address`. City is resolved by the data layer
  /// (hardcoded to 'Singapore' for MVP; extended when multi-city lands).
  final String venueName;
  final double latitude;
  final double longitude;
  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;

  /// 'auto' | 'manual'
  final String approvalMode;
  final String description;

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
    approvalMode,
    description,
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
  /// success. The data layer hardcodes costSplit='own' and city='Singapore'
  /// for the v1 MVP.
  Future<Either<Failure, Event>> createEvent(CreateEventParams params);

  /// Load a locally-persisted draft. Returns [null] when no draft exists.
  Future<Either<Failure, EventDraft?>> loadDraft();

  /// Persist [draft] locally (e.g., shared_preferences or local DB).
  /// Overwrites any existing draft.
  Future<Either<Failure, void>> saveDraft(EventDraft draft);

  /// Remove the locally-persisted draft. Idempotent — succeeds if no draft
  /// exists.
  Future<Either<Failure, void>> clearDraft();
}
