import 'package:equatable/equatable.dart';

import '../../domain/entities/join_request_with_event.dart';
import 'join_request_model.dart';

/// JSON model for the composite entry returned by GET /me/join-requests.
///
/// Wire shape:
/// ```json
/// {
///   "joinRequest": { ...JoinRequestResponse },
///   "event": {
///     "id": "...", "title": "...", "startsAt": "...", "endsAt": "...",
///     "venue": { "address": "...", "city": "..." },
///     "status": "...", "capacity": 8
///   }
/// }
/// ```
class JoinRequestWithEventModel extends Equatable {
  const JoinRequestWithEventModel({
    required this.joinRequest,
    required this.event,
  });

  factory JoinRequestWithEventModel.fromJson(Map<String, dynamic> json) {
    final eventJson = json['event'] as Map<String, dynamic>;
    final venueJson = eventJson['venue'] as Map<String, dynamic>;
    return JoinRequestWithEventModel(
      joinRequest: JoinRequestModel.fromJson(
        json['joinRequest'] as Map<String, dynamic>,
      ),
      event: JoinRequestEventSummaryModel(
        id: eventJson['id'] as String,
        title: eventJson['title'] as String,
        startsAt: DateTime.parse(eventJson['startsAt'] as String).toLocal(),
        endsAt: DateTime.parse(eventJson['endsAt'] as String).toLocal(),
        venueAddress: venueJson['address'] as String,
        venueCity: venueJson['city'] as String,
        status: eventJson['status'] as String,
        capacity: (eventJson['capacity'] as num).toInt(),
      ),
    );
  }

  final JoinRequestModel joinRequest;
  final JoinRequestEventSummaryModel event;

  JoinRequestWithEvent toEntity() => JoinRequestWithEvent(
    joinRequest: joinRequest.toEntity(),
    event: JoinRequestEventSummary(
      id: event.id,
      title: event.title,
      startsAt: event.startsAt,
      endsAt: event.endsAt,
      venueAddress: event.venueAddress,
      venueCity: event.venueCity,
      status: event.status,
      capacity: event.capacity,
    ),
  );

  @override
  List<Object?> get props => [joinRequest, event];
}

/// Sub-model for the embedded event summary in [JoinRequestWithEventModel].
/// Not a top-level domain entity — scoped to the data layer.
class JoinRequestEventSummaryModel extends Equatable {
  const JoinRequestEventSummaryModel({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.venueAddress,
    required this.venueCity,
    required this.status,
    required this.capacity,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String venueAddress;
  final String venueCity;
  final String status;
  final int capacity;

  @override
  List<Object?> get props => [
    id,
    title,
    startsAt,
    endsAt,
    venueAddress,
    venueCity,
    status,
    capacity,
  ];
}
