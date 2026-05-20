import 'package:equatable/equatable.dart';

import '../../domain/entities/review.dart';

/// JSON model mirroring the server's submit/edit review response shape.
///
/// Wire fields use ISO-8601 strings for dates. [toEntity()] converts to domain
/// types. No json_serializable generation — manual factory constructor per the
/// pattern established by [JoinRequestModel].
class ReviewModel extends Equatable {
  const ReviewModel({
    required this.id,
    required this.eventId,
    required this.raterUserId,
    required this.ratedUserId,
    required this.rating,
    required this.hidden,
    required this.createdAt,
    this.comment,
    this.hiddenAt,
    this.hiddenReason,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
    id: json['id'] as String,
    eventId: json['eventId'] as String,
    raterUserId: json['raterUserId'] as String,
    ratedUserId: json['ratedUserId'] as String,
    rating: (json['rating'] as num).toInt(),
    comment: json['comment'] as String?,
    hidden: (json['hidden'] as bool?) ?? false,
    hiddenAt: json['hiddenAt'] != null
        ? DateTime.parse(json['hiddenAt'] as String).toLocal()
        : null,
    hiddenReason: json['hiddenReason'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;
  final String eventId;
  final String raterUserId;
  final String ratedUserId;
  final int rating;
  final String? comment;
  final bool hidden;
  final DateTime? hiddenAt;
  final String? hiddenReason;
  final DateTime createdAt;

  Review toEntity() => Review(
    id: id,
    eventId: eventId,
    raterUserId: raterUserId,
    ratedUserId: ratedUserId,
    rating: rating,
    comment: comment,
    hidden: hidden,
    hiddenAt: hiddenAt,
    hiddenReason: hiddenReason,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    eventId,
    raterUserId,
    ratedUserId,
    rating,
    comment,
    hidden,
    hiddenAt,
    hiddenReason,
    createdAt,
  ];
}
