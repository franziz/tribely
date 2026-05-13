import 'package:equatable/equatable.dart';

import '../../domain/entities/join_request_with_requester.dart';
import 'join_request_model.dart';

/// JSON model for the composite entry returned by
/// GET /events/:id/join-requests (host pending list).
///
/// Wire shape:
/// ```json
/// {
///   "joinRequest": { ...JoinRequestResponse },
///   "requester": { "id": "...", "displayName": "..." }
/// }
/// ```
class JoinRequestWithRequesterModel extends Equatable {
  const JoinRequestWithRequesterModel({
    required this.joinRequest,
    required this.requester,
  });

  factory JoinRequestWithRequesterModel.fromJson(Map<String, dynamic> json) {
    final requesterJson = json['requester'] as Map<String, dynamic>;
    return JoinRequestWithRequesterModel(
      joinRequest: JoinRequestModel.fromJson(
        json['joinRequest'] as Map<String, dynamic>,
      ),
      requester: JoinRequestRequesterModel(
        id: requesterJson['id'] as String,
        displayName: requesterJson['displayName'] as String,
      ),
    );
  }

  final JoinRequestModel joinRequest;
  final JoinRequestRequesterModel requester;

  JoinRequestWithRequester toEntity() => JoinRequestWithRequester(
    joinRequest: joinRequest.toEntity(),
    requester: JoinRequestRequesterSummary(
      id: requester.id,
      displayName: requester.displayName,
    ),
  );

  @override
  List<Object?> get props => [joinRequest, requester];
}

/// Sub-model for the embedded requester summary in [JoinRequestWithRequesterModel].
/// Not a top-level domain entity — scoped to the data layer.
class JoinRequestRequesterModel extends Equatable {
  const JoinRequestRequesterModel({
    required this.id,
    required this.displayName,
  });

  final String id;
  final String displayName;

  @override
  List<Object?> get props => [id, displayName];
}
