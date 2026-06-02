import 'package:equatable/equatable.dart';

/// Mobile-domain vocabulary for join-request status.
///
/// The backend uses 'rejected' and 'cancelled'; the data layer translates
/// those to [declined] and [withdrawn] in [JoinRequestModel.toEntity()] so
/// the domain and UI use the same language the product spec describes.
enum JoinRequestStatus { pending, approved, declined, withdrawn, removedByHost }

/// Core domain entity representing a single join-request record.
/// Pure Dart — no JSON, no Flutter, no Riverpod.
class JoinRequest extends Equatable {
  const JoinRequest({
    required this.id,
    required this.eventId,
    required this.requesterUserId,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.decidedByUserId,
    this.decisionReason,
  });

  final String id;
  final String eventId;
  final String requesterUserId;
  final JoinRequestStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? decidedByUserId;
  final String? decisionReason;

  JoinRequest copyWith({
    String? id,
    String? eventId,
    String? requesterUserId,
    JoinRequestStatus? status,
    DateTime? requestedAt,
    DateTime? decidedAt,
    String? decidedByUserId,
    String? decisionReason,
  }) => JoinRequest(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    requesterUserId: requesterUserId ?? this.requesterUserId,
    status: status ?? this.status,
    requestedAt: requestedAt ?? this.requestedAt,
    decidedAt: decidedAt ?? this.decidedAt,
    decidedByUserId: decidedByUserId ?? this.decidedByUserId,
    decisionReason: decisionReason ?? this.decisionReason,
  );

  @override
  List<Object?> get props => [
    id,
    eventId,
    requesterUserId,
    status,
    requestedAt,
    decidedAt,
    decidedByUserId,
    decisionReason,
  ];
}
