import '../../domain/entities/report.dart';
import '../../domain/entities/report_reason.dart';

/// JSON deserialization DTO for a report returned by POST /reports.
///
/// [toEntity] converts to the pure-Dart [Report] domain entity.
class ReportModel {
  const ReportModel({
    required this.id,
    required this.reporterUserId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.createdAt,
    this.comment,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      reporterUserId: json['reporterUserId'] as String,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as String,
      reason: json['reason'] as String,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String reporterUserId;
  final String targetType;
  final String targetId;
  final String reason;
  final String? comment;
  final DateTime createdAt;

  Report toEntity() {
    return Report(
      id: id,
      reporterUserId: reporterUserId,
      targetType: targetType,
      targetId: targetId,
      reason: _parseReason(reason),
      comment: comment,
      createdAt: createdAt,
    );
  }

  static ReportReason _parseReason(String raw) {
    return ReportReason.values.firstWhere(
      (r) => r.wireValue == raw,
      orElse: () => ReportReason.other,
    );
  }
}
