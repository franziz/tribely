import 'package:equatable/equatable.dart';

import '../../domain/entities/join_request.dart';

/// JSON model mirroring the server's JoinRequestResponse shape.
///
/// Wire fields use backend vocabulary: status values are
/// 'pending' | 'approved' | 'rejected' | 'cancelled'.
/// [toEntity()] translates backend 'rejected' → [JoinRequestStatus.declined]
/// and 'cancelled' → [JoinRequestStatus.withdrawn] so the domain entity uses
/// product-spec language throughout.
class JoinRequestModel extends Equatable {
  const JoinRequestModel({
    required this.id,
    required this.eventId,
    required this.requesterUserId,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.decidedByUserId,
    this.decisionReason,
  });

  factory JoinRequestModel.fromJson(Map<String, dynamic> json) =>
      JoinRequestModel(
        id: json['id'] as String,
        eventId: json['eventId'] as String,
        requesterUserId: json['requesterUserId'] as String,
        status: json['status'] as String,
        requestedAt: DateTime.parse(json['requestedAt'] as String).toLocal(),
        decidedAt: json['decidedAt'] != null
            ? DateTime.parse(json['decidedAt'] as String).toLocal()
            : null,
        decidedByUserId: json['decidedByUserId'] as String?,
        decisionReason: json['decisionReason'] as String?,
      );

  /// Backend wire status — one of: pending, approved, rejected, cancelled.
  final String id;
  final String eventId;
  final String requesterUserId;
  final String status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? decidedByUserId;
  final String? decisionReason;

  JoinRequest toEntity() => JoinRequest(
    id: id,
    eventId: eventId,
    requesterUserId: requesterUserId,
    status: _mapStatus(status),
    requestedAt: requestedAt,
    decidedAt: decidedAt,
    decidedByUserId: decidedByUserId,
    decisionReason: decisionReason,
  );

  /// Translates backend status strings to mobile-domain [JoinRequestStatus].
  /// 'rejected' → declined  |  'cancelled' → withdrawn  (product-spec language).
  static JoinRequestStatus _mapStatus(String wire) => switch (wire) {
    'pending' => JoinRequestStatus.pending,
    'approved' => JoinRequestStatus.approved,
    'rejected' => JoinRequestStatus.declined,
    'cancelled' => JoinRequestStatus.withdrawn,
    _ => JoinRequestStatus.pending, // defensive fallback
  };

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
