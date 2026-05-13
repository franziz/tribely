import 'package:equatable/equatable.dart';

import '../../../events/domain/entities/event_category.dart';

/// Three-value time window for the Discover feed, per PM locked brief.
/// SGT boundary computation is deferred to D1 — this file only carries the
/// enum value that the repository serialises to a query param.
///
/// Wire values:
///   tonight  → `timeWindow=tonight`
///   thisWeek → `timeWindow=thisWeek`
///   anytime  → (param omitted entirely)
enum TimeWindow {
  tonight,
  thisWeek,
  anytime;

  /// Returns the query-param wire value, or null when the param should be
  /// omitted (i.e. [anytime]).
  String? get wireValue => switch (this) {
    TimeWindow.tonight => 'tonight',
    TimeWindow.thisWeek => 'thisWeek',
    TimeWindow.anytime => null,
  };
}

/// Immutable value object capturing all user-supplied filters for the Discover
/// browse endpoint.
///
/// Distance is always in kilometres — SG-first launch; no miles variant.
///
/// [lat] and [lng] are required when [maxDistanceKm] is non-null. The C1
/// LocationService provides them at call-site; B only specifies the shape.
class DiscoverFilters extends Equatable {
  const DiscoverFilters({
    this.timeWindow = TimeWindow.anytime,
    this.categories = const {},
    this.maxDistanceKm,
    this.lat,
    this.lng,
    this.cursor,
    this.limit = 20,
    this.hostUserId,
  }) : assert(
         maxDistanceKm == null || (lat != null && lng != null),
         'lat and lng must be provided when maxDistanceKm is set',
       );

  final TimeWindow timeWindow;

  /// Subset of [EventCategory] values the user wants to see. Empty set = all
  /// categories (param omitted).
  final Set<EventCategory> categories;

  /// Maximum radius from [lat]/[lng] in kilometres. Null = no distance filter.
  final double? maxDistanceKm;

  /// User's current latitude — only sent when [maxDistanceKm] is non-null.
  final double? lat;

  /// User's current longitude — only sent when [maxDistanceKm] is non-null.
  final double? lng;

  /// Opaque cursor returned by the previous page. Null = first page.
  /// The client never parses or generates cursor values.
  final String? cursor;

  /// Page size. Defaults to 20. Sent as `limit=<n>` query param.
  final int limit;

  /// Filter events by host user ID. Pass `'me'` for the authenticated user's
  /// hosted events (used by the Hosting tab). Null = no host filter.
  final String? hostUserId;

  /// Serialise to `GET /events` query parameters. Keys with null values are
  /// omitted so the API treats them as "no filter".
  Map<String, String> toQueryParams() {
    final params = <String, String>{};

    final tw = timeWindow.wireValue;
    if (tw != null) params['timeWindow'] = tw;

    if (categories.isNotEmpty) {
      params['categories'] = categories.map((c) => c.wireValue).join(',');
    }

    if (maxDistanceKm != null) {
      params['maxDistanceKm'] = maxDistanceKm!.toString();
      params['lat'] = lat!.toString();
      params['lng'] = lng!.toString();
    }

    if (cursor != null) params['cursor'] = cursor!;

    if (hostUserId != null) params['hostUserId'] = hostUserId!;

    params['limit'] = limit.toString();

    return params;
  }

  DiscoverFilters copyWith({
    TimeWindow? timeWindow,
    Set<EventCategory>? categories,
    Object? maxDistanceKm = _sentinel,
    Object? lat = _sentinel,
    Object? lng = _sentinel,
    Object? cursor = _sentinel,
    int? limit,
    Object? hostUserId = _sentinel,
  }) {
    return DiscoverFilters(
      timeWindow: timeWindow ?? this.timeWindow,
      categories: categories ?? this.categories,
      maxDistanceKm: maxDistanceKm == _sentinel
          ? this.maxDistanceKm
          : maxDistanceKm as double?,
      lat: lat == _sentinel ? this.lat : lat as double?,
      lng: lng == _sentinel ? this.lng : lng as double?,
      cursor: cursor == _sentinel ? this.cursor : cursor as String?,
      limit: limit ?? this.limit,
      hostUserId: hostUserId == _sentinel
          ? this.hostUserId
          : hostUserId as String?,
    );
  }

  @override
  List<Object?> get props => [
    timeWindow,
    categories,
    maxDistanceKm,
    lat,
    lng,
    cursor,
    limit,
    hostUserId,
  ];
}

// Sentinel for copyWith nullable-field overrides.
const Object _sentinel = Object();
