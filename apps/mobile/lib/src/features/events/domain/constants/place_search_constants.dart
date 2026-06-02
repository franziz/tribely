/// Mapbox proximity bias expressed as `lng,lat` (longitude first — Mapbox
/// convention, which is the reverse of the GeoJSON / Google Maps `lat,lng`
/// order).
// NOTE: lng,lat order for Mapbox — do not swap to lat,lng.
const String kSgProximityLngLat = '103.8198,1.3521';

/// ISO 3166-1 alpha-2 country filter.
const String kSgCountryCode = 'SG';

/// BCP-47 language tag for result language.
const String kSearchLanguage = 'en';

/// Maximum number of suggestions to request per typeahead call.
const int kSearchLimit = 8;

/// Comma-separated Mapbox feature types to include in results.
const String kSearchTypes = 'poi,address,place';

/// Debounce delay in milliseconds before firing a typeahead request.
const int kTypeaheadDebounceMs = 300;
