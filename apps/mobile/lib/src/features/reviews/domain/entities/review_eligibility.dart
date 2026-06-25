import 'package:equatable/equatable.dart';

/// Eligibility result for writing a review for a specific event's host.
///
/// Returned by `GET /events/:eventId/review-eligibility`.
///
/// The 24h–7d review window check is performed server-side — the endpoint
/// always returns 200; [eligible] == false means the current user is not in
/// the window (or has already reviewed this host for this event).
///
/// Pure Dart — no Flutter, no Dio, no Riverpod.
class ReviewEligibility extends Equatable {
  const ReviewEligibility({
    required this.eligible,
    this.ratedUserId,
    this.hostDisplayName,
  });

  /// Whether the current user may submit a review for this event's host.
  final bool eligible;

  /// The host's user ID. Non-null when [eligible] is true.
  final String? ratedUserId;

  /// The host's display name. Non-null when [eligible] is true.
  final String? hostDisplayName;

  @override
  List<Object?> get props => [eligible, ratedUserId, hostDisplayName];
}
