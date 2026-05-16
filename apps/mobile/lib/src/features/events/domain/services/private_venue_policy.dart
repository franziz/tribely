// SoT: apps/api/src/features/events/domain/services/private-venue-policy.ts — keep in sync
//
// Server is the authority for enforcement. This Dart mirror powers the inline
// UX warning on Step 2 of create-event only. Drift between server and mobile
// lists degrades the warning copy but never bypasses server enforcement.

import 'package:equatable/equatable.dart';

/// Reason a venue was classified as private.
enum PrivateVenueReason {
  /// The category is not in the public allowlist.
  categoryNotPublic,

  /// The venue name contains a private-venue keyword.
  keywordMatch,
}

/// Result of [detectPrivateVenue].
class PrivateVenueDetection extends Equatable {
  const PrivateVenueDetection({
    required this.isPrivate,
    this.reason,
    this.matchedKeyword,
  });

  final bool isPrivate;
  final PrivateVenueReason? reason;
  final String? matchedKeyword;

  @override
  List<Object?> get props => [isPrivate, reason, matchedKeyword];
}

/// Category values considered "public" — no private-venue permission required.
///
/// Mirrors [VenueCategory.PUBLIC_VALUES] in
/// `apps/api/src/features/events/domain/value-objects/venue-category.ts`.
const Set<String> _publicValues = {
  'hawker_centre',
  'park',
  'museum',
  'restaurant',
  'bar',
  'cafe',
  'beach',
  'mrt_landmark',
  'library',
  'community_centre',
  'shopping_mall_common_area',
  'tourist_attraction',
};

/// Keywords that indicate a private/residential venue when found in the venue
/// name. Sorted longest-first for greedy matching — a more specific keyword
/// wins over a shorter one embedded inside it (e.g. "condominium" before
/// "condo").
///
/// NOTE: "block" is intentionally absent — HDB block addresses
/// ("Block 335 Smith St") are public and would produce false positives for
/// Singapore users.
///
/// Mirrors [PRIVATE_KEYWORDS] in
/// `apps/api/src/features/events/domain/services/private-venue-policy.ts`.
const List<String> _privateKeywords = [
  'condominium',
  'apartment',
  'my place',
  'my flat',
  'my room',
  'airbnb',
  'studio',
  'hostel',
  'condo',
  'hotel',
  'motel',
  'house',
  'home',
  'unit',
  'apt',
];

/// Detects whether a venue is "private" per the TRI-33 client-side mirror.
///
/// **Server is the authority.** This mirror powers the inline UX warning only;
/// drift between server and mobile lists degrades warning copy but never
/// bypasses server enforcement.
///
/// [categoryValue] is a raw string (nullable for the case where the host has
/// not selected a category yet). A null category falls through to the keyword
/// check — if no keyword matches, the result is not-private.
///
/// [venueName] is the host's free-text venue label.
///
/// Algorithm:
/// 1. If [categoryValue] is non-null and NOT in the public allowlist →
///    [PrivateVenueReason.categoryNotPublic].
/// 2. Lowercase [venueName] once. For each keyword in [_privateKeywords]
///    (longest-first), if the lowercased name contains the keyword →
///    [PrivateVenueReason.keywordMatch].
/// 3. Otherwise → not private.
PrivateVenueDetection detectPrivateVenue({
  required String? categoryValue,
  required String venueName,
}) {
  if (categoryValue != null && !_publicValues.contains(categoryValue)) {
    return const PrivateVenueDetection(
      isPrivate: true,
      reason: PrivateVenueReason.categoryNotPublic,
    );
  }

  final lower = venueName.toLowerCase();
  for (final keyword in _privateKeywords) {
    if (lower.contains(keyword)) {
      return PrivateVenueDetection(
        isPrivate: true,
        reason: PrivateVenueReason.keywordMatch,
        matchedKeyword: keyword,
      );
    }
  }

  return const PrivateVenueDetection(isPrivate: false);
}
