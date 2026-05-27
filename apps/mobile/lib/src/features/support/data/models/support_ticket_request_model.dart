import '../../domain/entities/support_ticket_draft.dart';

/// Serializes a [SupportTicketDraft] into the JSON body expected by
/// POST /support/tickets.
///
/// `reportId` is omitted entirely when null — the backend treats its absence
/// as "no linked report" and would reject an explicit empty string.
class SupportTicketRequestModel {
  const SupportTicketRequestModel({
    required this.category,
    required this.message,
    this.reportId,
  });

  factory SupportTicketRequestModel.fromDraft(SupportTicketDraft draft) {
    return SupportTicketRequestModel(
      category: draft.category.wireValue,
      message: draft.message,
      reportId: draft.reportId,
    );
  }

  final String category;
  final String message;
  final String? reportId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'category': category,
      'message': message,
      // Omit reportId when null — do NOT send empty string.
      if (reportId != null) 'reportId': reportId,
    };
  }
}
