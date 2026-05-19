import 'package:equatable/equatable.dart';

/// A single review written by one Tribely user about another,
/// following participation in a shared event.
///
/// Pure Dart — no Flutter, no Dio, no Riverpod.
class Review extends Equatable {
  const Review({
    required this.id,
    required this.eventId,
    required this.raterUserId,
    required this.ratedUserId,
    required this.rating,
    required this.createdAt,
    required this.hidden,
    this.comment,
    this.hiddenAt,
    this.hiddenReason,
  });

  final String id;
  final String eventId;
  final String raterUserId;
  final String ratedUserId;

  /// Whole stars 1–5. Never zero after construction.
  final int rating;

  /// Optional free-text, max 500 chars. Null means no comment was left.
  final String? comment;

  final DateTime createdAt;

  /// True when Tribely moderation has suppressed this review.
  final bool hidden;

  final DateTime? hiddenAt;
  final String? hiddenReason;

  Review copyWith({
    String? id,
    String? eventId,
    String? raterUserId,
    String? ratedUserId,
    int? rating,
    String? comment,
    DateTime? createdAt,
    bool? hidden,
    DateTime? hiddenAt,
    String? hiddenReason,
  }) => Review(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    raterUserId: raterUserId ?? this.raterUserId,
    ratedUserId: ratedUserId ?? this.ratedUserId,
    rating: rating ?? this.rating,
    comment: comment ?? this.comment,
    createdAt: createdAt ?? this.createdAt,
    hidden: hidden ?? this.hidden,
    hiddenAt: hiddenAt ?? this.hiddenAt,
    hiddenReason: hiddenReason ?? this.hiddenReason,
  );

  @override
  List<Object?> get props => [
    id,
    eventId,
    raterUserId,
    ratedUserId,
    rating,
    comment,
    createdAt,
    hidden,
    hiddenAt,
    hiddenReason,
  ];
}
