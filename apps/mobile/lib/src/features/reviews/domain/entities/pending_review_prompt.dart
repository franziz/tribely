import 'package:equatable/equatable.dart';

/// Represents a single pending review prompt returned by
/// `GET /me/pending-review-prompts`.
///
/// Carries the minimum information needed to:
///   - Render the foreground banner in My Events.
///   - Pre-populate the review composer on tap.
///
/// Pure Dart — no Flutter, no Dio, no Riverpod.
class PendingReviewPrompt extends Equatable {
  const PendingReviewPrompt({
    required this.eventId,
    required this.eventTitle,
    required this.eventEndedAt,
    required this.ratedUserId,
    required this.ratedUserDisplayName,
    this.ratedUserAvatarUrl,
  });

  final String eventId;
  final String eventTitle;

  /// When the event ended. Used for the date caption in the banner.
  final DateTime eventEndedAt;

  final String ratedUserId;
  final String ratedUserDisplayName;

  /// May be null when the counterpart has not uploaded a selfie.
  final String? ratedUserAvatarUrl;

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
