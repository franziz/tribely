import '../../domain/repositories/support_repository.dart';

/// JSON deserialization DTO for a ticket returned by POST /support/tickets.
///
/// [toEntity] converts to the pure-Dart [SubmitResult] domain type.
class SupportTicketResponseModel {
  const SupportTicketResponseModel({required this.id, required this.createdAt});

  factory SupportTicketResponseModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketResponseModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final DateTime createdAt;

  SubmitResult toEntity() => SubmitResult(id: id, createdAt: createdAt);
}
