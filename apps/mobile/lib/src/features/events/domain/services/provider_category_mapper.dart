/// Maps a raw Mapbox `poi_category` string to one of Tribely's 12 public
/// venue-category strings (see [VenueCategory.publicValues]).
///
/// Returns null when [rawProviderCategory] is null or does not map to a known
/// category — the user will be prompted to pick a category chip manually.
///
/// Mappings are case-sensitive lowercase, matching Mapbox's returned values.
/// Only the 12 public VenueCategory values are targets; private categories
/// (apartment, condo, home, hotel, hostel, other) are intentionally excluded
/// because Mapbox POI search does not return residential/private venues.
String? mapProviderCategoryToVenueCategory(String? rawProviderCategory) {
  if (rawProviderCategory == null) return null;

  switch (rawProviderCategory) {
    // --- Direct matches ---
    case 'restaurant':
      return 'restaurant';
    case 'park':
      return 'park';
    case 'museum':
      return 'museum';
    case 'beach':
      return 'beach';
    case 'library':
      return 'library';

    // --- bar: Mapbox uses both 'bar' and 'pub' for licensed premises ---
    case 'bar':
    case 'pub':
      return 'bar';

    // --- cafe: Mapbox uses 'cafe' and 'coffee_shop' interchangeably ---
    case 'cafe':
    case 'coffee_shop':
      return 'cafe';

    // --- hawker_centre: Mapbox uses 'hawker' for Singapore hawker centres ---
    case 'hawker':
      return 'hawker_centre';

    // --- mrt_landmark: Mapbox uses 'transit_station' for MRT stops ---
    case 'transit_station':
      return 'mrt_landmark';

    // --- community_centre: Mapbox uses 'community_center' (US spelling) ---
    case 'community_center':
    case 'community_centre':
      return 'community_centre';

    // --- shopping_mall_common_area: Mapbox uses 'shopping_mall' ---
    case 'shopping_mall':
      return 'shopping_mall_common_area';

    // --- tourist_attraction: Mapbox uses 'tourist_attraction' directly ---
    case 'tourist_attraction':
      return 'tourist_attraction';

    default:
      return null;
  }
}
