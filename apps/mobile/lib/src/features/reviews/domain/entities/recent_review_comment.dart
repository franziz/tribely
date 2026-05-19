import 'package:equatable/equatable.dart';

/// Condensed view of a recent review comment for use in profile aggregates.
///
/// Only public-facing fields — no hidden/moderation state. The server already
/// applies filtering before returning these in the aggregate endpoint.
///
/// Pure Dart — no Flutter, no Dio, no Riverpod.
class RecentReviewComment extends Equatable {
  const RecentReviewComment({
    required this.excerpt,
    required this.raterDisplayName,
    required this.rating,
    required this.eventTitle,
    required this.createdAt,
  });

  /// Truncated comment text (server-side). May be the full comment if short.
  final String excerpt;

  final String raterDisplayName;

  /// Whole stars 1–5.
  final int rating;

  final String eventTitle;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    excerpt,
    raterDisplayName,
    rating,
    eventTitle,
    createdAt,
  ];
}
