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

  /// Fetches the authenticated user's own hosted events from `GET /me/events`.
  /// Requires a valid Bearer token (API client handles injection automatically).
  Future<EventPageResponse> listMyHostedEvents();
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
  Future<EventPageResponse> listMyHostedEvents() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/events');
    return EventPageResponse.fromJson(response.data!);
  }

  @override
  Future<EventModel> getEventDetail(String eventId) async {
    final response = await _dio.get<Map<String, dynamic>>('/events/$eventId');
    // GET /events/:id returns a WRAPPER: { event: {...inner shape...}, host: { id, displayName, isVerified } }
    // (see apps/api/src/features/events/presentation/http/schemas/event.schemas.ts:91-94,
    // eventWithHostResponseSchema). EventModel is no longer a 1:1 mirror of eventResponseSchema —
    // it carries synthesised `hostDisplayName` AND `hostIsVerified` flattened from the wrapper's
    // `host` sibling. host.avatarUrl + goingCount remain deferred to TRI-19.
    final wrapper = response.data!;
    final inner = wrapper['event'] as Map<String, dynamic>;
    final host = wrapper['host'] as Map<String, dynamic>?;
    final hostDisplayName = host?['displayName'] as String?;
    final synthesized = <String, dynamic>{
      ...inner,
      'hostDisplayName': hostDisplayName,
      // Flatten host.isVerified from the wrapper into the synthesised map.
      // Defensive `?? false` per TRI-86 §2: absent/null wire field resolves
      // to false, never throws. This is correct for browseEvents / listing
      // paths too (they hit json['hostIsVerified'] = null → ?? false).
      'hostIsVerified': (host?['isVerified'] as bool?) ?? false,
    };
    return EventModel.fromJson(synthesized);
  }
}
