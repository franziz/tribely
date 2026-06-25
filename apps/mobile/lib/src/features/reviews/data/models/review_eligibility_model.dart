import 'package:equatable/equatable.dart';

import '../../domain/entities/review_eligibility.dart';

/// JSON model for the response shape of
/// `GET /events/:eventId/review-eligibility`.
///
/// Wire shape:
/// ```json
/// { "eligible": true, "ratedUserId": "...", "hostDisplayName": "..." }
/// ```
///
/// The endpoint always returns 200; [eligible] == false indicates the caller
/// is outside the 24h–7d review window or has already reviewed this host.
class ReviewEligibilityModel extends Equatable {
  const ReviewEligibilityModel({
    required this.eligible,
    this.ratedUserId,
    this.hostDisplayName,
  });

  factory ReviewEligibilityModel.fromJson(Map<String, dynamic> json) =>
      ReviewEligibilityModel(
        eligible: json['eligible'] as bool,
        ratedUserId: json['ratedUserId'] as String?,
        hostDisplayName: json['hostDisplayName'] as String?,
      );

  final bool eligible;
  final String? ratedUserId;
  final String? hostDisplayName;

  ReviewEligibility toEntity() => ReviewEligibility(
    eligible: eligible,
    ratedUserId: ratedUserId,
    hostDisplayName: hostDisplayName,
  );

  @override
  List<Object?> get props => [eligible, ratedUserId, hostDisplayName];
}
