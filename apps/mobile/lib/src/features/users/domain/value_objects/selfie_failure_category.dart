/// Mirrors the backend `SelfieFailureCategory` literal union.
///
/// The string values MUST match the backend snake_case literals exactly —
/// they are used as JSON keys over the wire.
enum SelfieFailureCategory {
  poorLighting,
  faceNotVisible,
  qualityTooLow,
  other;

  /// Deserialises from the backend snake_case wire value.
  ///
  /// Returns `null` for any unrecognised string so callers can decide whether
  /// to treat it as [other] or surface an unknown category. Callers that want
  /// a non-nullable value should `.??  SelfieFailureCategory.other`.
  static SelfieFailureCategory? fromJson(String? value) => switch (value) {
    'poor_lighting' => poorLighting,
    'face_not_visible' => faceNotVisible,
    'quality_too_low' => qualityTooLow,
    'other' => other,
    _ => null,
  };

  /// Serialises back to the backend snake_case wire value.
  String toJson() => switch (this) {
    poorLighting => 'poor_lighting',
    faceNotVisible => 'face_not_visible',
    qualityTooLow => 'quality_too_low',
    other => 'other',
  };
}
