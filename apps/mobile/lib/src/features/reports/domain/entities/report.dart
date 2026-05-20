import 'package:equatable/equatable.dart';

import 'report_reason.dart';

/// A report filed by one user against a content target (e.g. a review).
///
/// Pure Dart — no Flutter, no Dio, no Riverpod.
class Report extends Equatable {
  const Report({
    required this.id,
    required this.reporterUserId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final String reporterUserId;

  /// The type of entity being reported (e.g. 'review').
  final String targetType;

  /// The ID of the entity being reported.
  final String targetId;

  final ReportReason reason;

  /// Optional free-text elaboration, max 500 chars.
  final String? comment;

  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    reporterUserId,
    targetType,
    targetId,
    reason,
    comment,
    createdAt,
  ];
}
