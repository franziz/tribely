// Validation constants — server sources cited per constant.
//
// Server SoT files:
//   Title / description bounds  → apps/api/src/features/events/domain/entities/event.ts (TITLE_MIN, TITLE_MAX, DESCRIPTION_MAX)
//   Capacity bounds             → apps/api/src/features/events/domain/value-objects/capacity.ts (MIN, MAX)
//   Venue address/city bounds   → apps/api/src/features/events/domain/value-objects/venue.ts (ADDRESS_MIN/MAX, CITY_MIN/MAX)
//   Lat/lng ranges              → apps/api/src/features/events/domain/value-objects/venue.ts
//
// UI-only tightenings (not enforced server-side) are documented inline.

import '../entities/event_category.dart';

// ---------------------------------------------------------------------------
// Title
// ---------------------------------------------------------------------------

/// Mirrors server TITLE_MIN (event.ts:16).
const int titleMinLen = 3;

/// Mirrors server TITLE_MAX (event.ts:17).
const int titleMaxLen = 120;

// ---------------------------------------------------------------------------
// Description
// ---------------------------------------------------------------------------

/// Mirrors server DESCRIPTION_MAX (event.ts:18).
const int descriptionMaxLen = 2000;

/// UI-only minimum — required field per AC #6. Server allows null; the form
/// requires at least this many characters before the user can advance.
const int descriptionMinLenUi = 20;

// ---------------------------------------------------------------------------
// Capacity
// ---------------------------------------------------------------------------

/// Mirrors server Capacity.MIN (capacity.ts:3).
const int capacityMin = 2;

/// Mirrors server Capacity.MAX (capacity.ts:4).
const int capacityMax = 1000;

/// UI-only upper clamp per PM brief. Displayed as the slider maximum so the
/// form stays usable; the server still accepts up to [capacityMax].
const int capacityUiClamp = 50;

// ---------------------------------------------------------------------------
// Venue
// ---------------------------------------------------------------------------

/// Mirrors server ADDRESS_MIN (venue.ts:3).
const int venueAddressMinLen = 1;

/// Mirrors server ADDRESS_MAX (venue.ts:4).
const int venueAddressMaxLen = 300;

/// Mirrors server CITY_MIN (venue.ts:5).
const int venueCityMinLen = 1;

/// Mirrors server CITY_MAX (venue.ts:6).
const int venueCityMaxLen = 120;

// ---------------------------------------------------------------------------
// Lat / lng
// ---------------------------------------------------------------------------

/// Mirrors server latitude validation (venue.ts).
const double latitudeMin = -90;
const double latitudeMax = 90;

/// Mirrors server longitude validation (venue.ts).
const double longitudeMin = -180;
const double longitudeMax = 180;

// ---------------------------------------------------------------------------
// Cost notes (forward-compat)
// ---------------------------------------------------------------------------

/// UI-only maximum for the deferred cost-notes field. Not enforced server-side
/// in v1 because the field is not yet submitted.
const int costNotesMaxLen = 200;

// ---------------------------------------------------------------------------
// Pure validator functions — return null on valid, error message on invalid.
// No side effects. Used by form fields and the pre-submit guard.
// ---------------------------------------------------------------------------

String? validateTitle(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Title is required';
  }
  final trimmed = value.trim();
  if (trimmed.length < titleMinLen) {
    return 'Title must be at least $titleMinLen characters';
  }
  if (trimmed.length > titleMaxLen) {
    return 'Title must be at most $titleMaxLen characters';
  }
  return null;
}

String? validateCategory(EventCategory? value) {
  if (value == null) return 'Category is required';
  return null;
}

String? validateVenueName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Venue name is required';
  }
  final trimmed = value.trim();
  if (trimmed.length < venueAddressMinLen) {
    return 'Venue name must be at least $venueAddressMinLen character';
  }
  if (trimmed.length > venueAddressMaxLen) {
    return 'Venue name must be at most $venueAddressMaxLen characters';
  }
  return null;
}

String? validateLatitude(double? value) {
  if (value == null) return 'Latitude is required';
  if (value < latitudeMin || value > latitudeMax) {
    return 'Latitude must be between $latitudeMin and $latitudeMax';
  }
  return null;
}

String? validateLongitude(double? value) {
  if (value == null) return 'Longitude is required';
  if (value < longitudeMin || value > longitudeMax) {
    return 'Longitude must be between $longitudeMin and $longitudeMax';
  }
  return null;
}

/// [startsAt] must be in the future (relative to now at validation time).
String? validateStartsAt(DateTime? value) {
  if (value == null) return 'Start time is required';
  if (!value.isAfter(DateTime.now())) {
    return 'Start time must be in the future';
  }
  return null;
}

/// [endsAt] must be strictly after [startsAt].
String? validateEndsAt(DateTime? value, DateTime? startsAt) {
  if (value == null) return 'End time is required';
  if (startsAt != null && !value.isAfter(startsAt)) {
    return 'End time must be after start time';
  }
  return null;
}

String? validateCapacity(int? value) {
  if (value == null) return 'Capacity is required';
  if (value < capacityMin) {
    return 'Capacity must be at least $capacityMin';
  }
  if (value > capacityMax) {
    return 'Capacity must be at most $capacityMax';
  }
  return null;
}

String? validateApprovalMode(String? value) {
  if (value == null || value.isEmpty) return 'Approval mode is required';
  if (value != 'auto' && value != 'manual') {
    return "Approval mode must be 'auto' or 'manual'";
  }
  return null;
}

/// Description is required by the form (UI-only minimum [descriptionMinLenUi]).
/// The server allows null; we tighten here per AC #6.
String? validateDescription(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Description is required';
  }
  final trimmed = value.trim();
  if (trimmed.length < descriptionMinLenUi) {
    return 'Description must be at least $descriptionMinLenUi characters';
  }
  if (trimmed.length > descriptionMaxLen) {
    return 'Description must be at most $descriptionMaxLen characters';
  }
  return null;
}
