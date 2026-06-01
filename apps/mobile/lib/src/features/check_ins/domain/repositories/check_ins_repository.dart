import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/pending_check_in.dart';

/// Outbound port for the check-ins bounded context.
///
/// All methods return `Either<Failure, T>` — never throw. Concrete
/// implementations live in `data/repositories/`.
abstract class CheckInsRepository {
  /// Fetches pending post-event check-ins for the authenticated user.
  /// Maps to `GET /me/post-event-check-ins`.
  Future<Either<Failure, List<PendingCheckIn>>> surfacePending();

  /// Marks a check-in as acknowledged by the attendee.
  /// Maps to `POST /me/post-event-check-ins/:id/acknowledge`.
  Future<Either<Failure, Unit>> acknowledge(String checkInId);

  /// Flags a check-in for safety review, attaching a free-text report body.
  /// Maps to `POST /me/post-event-check-ins/:id/flag`.
  ///
  /// [disclaimerAcknowledged] must be `true` — the caller (use case) passes
  /// through the value recorded by the UI gate; the API persists it for audit.
  Future<Either<Failure, Unit>> flag(
    String checkInId,
    String reportBody,
    bool disclaimerAcknowledged,
  );
}
