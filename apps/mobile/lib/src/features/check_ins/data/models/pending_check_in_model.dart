import '../../domain/entities/pending_check_in.dart';

/// JSON DTO for `GET /me/post-event-check-ins` response items.
///
/// Field names match the wire format exactly (camelCase from the API).
class PendingCheckInModel {
  const PendingCheckInModel({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.hostDisplayName,
    required this.endedAt,
    required this.createdAt,
  });

  factory PendingCheckInModel.fromJson(Map<String, dynamic> json) =>
      PendingCheckInModel(
        id: json['id'] as String,
        eventId: json['eventId'] as String,
        eventTitle: json['eventTitle'] as String,
        hostDisplayName: json['hostDisplayName'] as String,
        endedAt: DateTime.parse(json['endedAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String eventId;
  final String eventTitle;
  final String hostDisplayName;
  final DateTime endedAt;
  final DateTime createdAt;

  PendingCheckIn toEntity() => PendingCheckIn(
    id: id,
    eventId: eventId,
    eventTitle: eventTitle,
    hostDisplayName: hostDisplayName,
    endedAt: endedAt,
    createdAt: createdAt,
  );
}
