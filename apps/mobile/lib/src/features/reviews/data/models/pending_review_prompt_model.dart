import 'package:equatable/equatable.dart';

import '../../domain/entities/pending_review_prompt.dart';

/// JSON model for the response shape of `GET /me/pending-review-prompts`.
///
/// Wire shape:
/// ```json
/// { "prompt": { ... } | null }
/// ```
///
/// Use [fromResponseJson] to parse the top-level envelope.
/// Use [fromPromptJson] to parse the inner prompt object.
class PendingReviewPromptModel extends Equatable {
  const PendingReviewPromptModel({
    required this.eventId,
    required this.eventTitle,
    required this.eventEndedAt,
    required this.ratedUserId,
    required this.ratedUserDisplayName,
    this.ratedUserAvatarUrl,
  });

  /// Parses the inner prompt object (`json['prompt']`).
  factory PendingReviewPromptModel.fromPromptJson(Map<String, dynamic> json) =>
      PendingReviewPromptModel(
        eventId: json['eventId'] as String,
        eventTitle: json['eventTitle'] as String,
        eventEndedAt: DateTime.parse(json['eventEndedAt'] as String).toLocal(),
        ratedUserId: json['ratedUserId'] as String,
        ratedUserDisplayName: json['ratedUserDisplayName'] as String,
        ratedUserAvatarUrl: json['ratedUserAvatarUrl'] as String?,
      );

  final String eventId;
  final String eventTitle;
  final DateTime eventEndedAt;
  final String ratedUserId;
  final String ratedUserDisplayName;
  final String? ratedUserAvatarUrl;

  PendingReviewPrompt toEntity() => PendingReviewPrompt(
    eventId: eventId,
    eventTitle: eventTitle,
    eventEndedAt: eventEndedAt,
    ratedUserId: ratedUserId,
    ratedUserDisplayName: ratedUserDisplayName,
    ratedUserAvatarUrl: ratedUserAvatarUrl,
  );

  @override
  List<Object?> get props => [
    eventId,
    eventTitle,
    eventEndedAt,
    ratedUserId,
    ratedUserDisplayName,
    ratedUserAvatarUrl,
  ];
}
