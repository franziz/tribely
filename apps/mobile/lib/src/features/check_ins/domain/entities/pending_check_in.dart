import 'package:equatable/equatable.dart';

/// A post-event check-in that has been surfaced to the attendee for
/// acknowledgement or flagging. Immutable value object — pure Dart.
class PendingCheckIn extends Equatable {
  const PendingCheckIn({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.hostDisplayName,
    required this.endedAt,
    required this.createdAt,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String hostDisplayName;
  final DateTime endedAt;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    eventId,
    eventTitle,
    hostDisplayName,
    endedAt,
    createdAt,
  ];
}
