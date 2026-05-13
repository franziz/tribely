import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../events/domain/entities/event.dart';
import '../entities/discover_filters.dart';
import '../entities/event_page.dart';

/// Port: outbound interface for the Discover data layer.
///
/// Implementations live in `data/repositories/discover_repository_impl.dart`.
/// Domain and application layers depend only on this interface.
abstract class DiscoverRepository {
  /// Fetch a paginated list of publicly-visible events matching [filters].
  ///
  /// Returns [EventPage] on success — [EventPage.nextCursor] is non-null when
  /// more pages exist.
  ///
  /// Possible failures: [AuthFailure] (401), [ServerFailure] (5xx),
  /// [NetworkFailure] (no connectivity).
  Future<Either<Failure, EventPage>> browseEvents(DiscoverFilters filters);

  /// Fetch the full detail of a single event by its [eventId].
  ///
  /// Returns [NotFoundFailure] when the server responds with 404.
  ///
  /// Possible failures: [NotFoundFailure] (404), [AuthFailure] (401),
  /// [ServerFailure] (5xx), [NetworkFailure] (no connectivity).
  Future<Either<Failure, Event>> getEventDetail(String eventId);

  /// Fetch the authenticated user's own hosted events from `GET /me/events`.
  ///
  /// Requires a valid Bearer token — callers must ensure the user is
  /// authenticated before invoking.
  ///
  /// Possible failures: [AuthFailure] (401), [ServerFailure] (5xx),
  /// [NetworkFailure] (no connectivity).
  Future<Either<Failure, List<Event>>> listMyHostedEvents();
}
