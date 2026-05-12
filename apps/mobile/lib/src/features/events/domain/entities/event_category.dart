// SoT: apps/api/src/features/events/domain/value-objects/event-category.ts — keep in sync

/// The seven category variants that an event can belong to.
/// Wire values are snake_case strings matching the server enum exactly.
enum EventCategory {
  drinks,
  food,
  hike,
  museum,
  sports,
  nightlife,
  other;

  /// The snake_case wire value sent to and received from the server.
  String get wireValue => name;

  /// Title-Case display name for UI labels.
  String get displayName => switch (this) {
    EventCategory.drinks => 'Drinks',
    EventCategory.food => 'Food',
    EventCategory.hike => 'Hike',
    EventCategory.museum => 'Museum',
    EventCategory.sports => 'Sports',
    EventCategory.nightlife => 'Nightlife',
    EventCategory.other => 'Other',
  };

  /// Defensive parser: unknown values fall back to [EventCategory.other]
  /// instead of throwing, so unrecognised future server values don't crash
  /// the client.
  static EventCategory fromWire(String value) {
    return EventCategory.values.firstWhere(
      (e) => e.wireValue == value,
      orElse: () => EventCategory.other,
    );
  }
}
