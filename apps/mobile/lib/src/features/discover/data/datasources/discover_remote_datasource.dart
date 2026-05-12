import 'package:dio/dio.dart';

import '../../../events/data/models/event_model.dart';
import '../../domain/entities/discover_filters.dart';

/// Response shape for `GET /events` — a page of event models plus an opaque
/// next-cursor string.
class EventPageResponse {
  const EventPageResponse({required this.events, required this.nextCursor});

  factory EventPageResponse.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] as List<dynamic>;
    return EventPageResponse(
      events: rawEvents
          .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }

  final List<EventModel> events;
  final String? nextCursor;
}

/// Driving-adapter interface for the Discover remote API.
///
/// Throws [DioException] on network or server errors — does NOT return Either.
/// The repository maps DioExceptions to domain [Failure] types.
abstract class DiscoverRemoteDatasource {
  /// Fetches a page of events matching [filters] from `GET /events`.
  Future<EventPageResponse> browseEvents(DiscoverFilters filters);

  /// Fetches the full detail of a single event from `GET /events/:id`.
  Future<EventModel> getEventDetail(String eventId);
}

class DiscoverRemoteDatasourceImpl implements DiscoverRemoteDatasource {
  DiscoverRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<EventPageResponse> browseEvents(DiscoverFilters filters) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events',
      queryParameters: filters.toQueryParams(),
    );
    return EventPageResponse.fromJson(response.data!);
  }

  @override
  Future<EventModel> getEventDetail(String eventId) async {
    final response = await _dio.get<Map<String, dynamic>>('/events/$eventId');
    // GET /events/:id returns a WRAPPER: { event: {...inner shape...}, host: { id, displayName } }
    // (see apps/api/src/features/events/presentation/http/schemas/event.schemas.ts:91-94,
    // eventWithHostResponseSchema). EventModel.fromJson expects the INNER shape, so we
    // unwrap here. The `host` sibling is intentionally unused — v1 detail page falls back
    // to "Hosted by ${event.hostId}"; a Host projection belongs with the TRI-19 follow-up.
    final inner = response.data!['event'] as Map<String, dynamic>;
    return EventModel.fromJson(inner);
  }
}
