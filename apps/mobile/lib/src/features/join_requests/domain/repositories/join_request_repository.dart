import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/join_request.dart';
import '../entities/join_request_with_event.dart';
import '../entities/join_request_with_requester.dart';

/// Port — implemented in data/repositories/join_request_repository_impl.dart.
/// All methods return [Either<Failure, T>]; throwing is not part of the contract.
abstract class JoinRequestRepository {
  /// POST /events/:eventId/join-requests
  Future<Either<Failure, JoinRequest>> requestToJoin({required String eventId});

  /// POST /join-requests/:id/approve
  Future<Either<Failure, JoinRequest>> approve({required String joinRequestId});

  /// POST /join-requests/:id/reject  (body: { reason })
  /// UI calls this "decline" but the endpoint verb is "reject".
  Future<Either<Failure, JoinRequest>> decline({
    required String joinRequestId,
    String? reason,
  });

  /// DELETE /join-requests/:id
  Future<Either<Failure, void>> withdraw({required String joinRequestId});

  /// GET /events/:eventId/join-requests  (host view — pending only)
  Future<Either<Failure, List<JoinRequestWithRequester>>> listPendingForEvent({
    required String eventId,
  });

  /// GET /events/:eventId/join-requests?status=approved  (host view — approved/attending)
  Future<Either<Failure, List<JoinRequestWithRequester>>> listApprovedForEvent({
    required String eventId,
  });

  /// GET /me/join-requests?eventId=...  (joiner view; eventId is optional)
  Future<Either<Failure, List<JoinRequestWithEvent>>> listMyJoinRequests({
    String? eventId,
  });

  /// POST /events/:eventId/join-requests/:joinRequestId/remove  (host action)
  ///
  /// Removes an approved attendee from the event. [reason] is mandatory on the
  /// wire (backend enforces non-empty).
  Future<Either<Failure, Unit>> removeAttendee({
    required String eventId,
    required String joinRequestId,
    required String reason,
  });
}
