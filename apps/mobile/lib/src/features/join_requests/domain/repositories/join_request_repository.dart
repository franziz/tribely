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

  /// GET /me/join-requests?eventId=...  (joiner view; eventId is optional)
  Future<Either<Failure, List<JoinRequestWithEvent>>> listMyJoinRequests({
    String? eventId,
  });
}
