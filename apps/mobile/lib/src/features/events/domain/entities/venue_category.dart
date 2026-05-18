// SoT: apps/api/src/features/events/domain/value-objects/venue-category.ts — keep in sync
//
// This is the closed-set Dart equivalent of the server's VenueCategory value
// object. Used by the create-event flow to classify venue selection as public
// or private. Brief 10's private_venue_policy.dart has its own copy of these
// values (it predates this file); do NOT refactor it to import from here.

/// Utility class for venue category classification.
///
/// Categories are raw snake_case strings matching the server enum exactly.
/// [publicValues] mirrors VenueCategory.PUBLIC_VALUES on the server;
/// [privateValues] mirrors VenueCategory.PRIVATE_VALUES.
class VenueCategory {
  VenueCategory._();

  static const Set<String> publicValues = {
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

  static const Set<String> privateValues = {
    'apartment',
    'condo',
    'home',
    'hotel',
    'hostel',
    'other',
  };

  static const Set<String> values = {...publicValues, ...privateValues};

  /// Returns true when [value] is a recognised category.
  static bool isValid(String value) => values.contains(value);

  /// Returns true when [value] is a public-venue category.
  static bool isPublic(String value) => publicValues.contains(value);
}
