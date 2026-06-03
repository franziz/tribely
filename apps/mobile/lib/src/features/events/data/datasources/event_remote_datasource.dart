import 'package:dio/dio.dart';

import '../models/create_event_params_model.dart';
import '../models/event_model.dart';

/// Driving-adapter interface for the events remote API.
///
/// This datasource throws [DioException] on network or server errors — it does
/// NOT return Either. The repository (EventRepositoryImpl) maps
/// DioExceptions to domain [Failure] types. This matches the established
/// pattern in auth_remote_datasource.dart.
abstract class EventRemoteDatasource {
  Future<EventModel> createEvent(CreateEventParamsModel params);

  /// Cancel a published event. The server returns 204 No Content on success.
  /// Throws [DioException] on network or server errors.
  Future<void> cancelEvent(String eventId);
}

class EventRemoteDatasourceImpl implements EventRemoteDatasource {
  EventRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<EventModel> createEvent(CreateEventParamsModel params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/events',
      data: params.toJson(),
    );
    return EventModel.fromJson(response.data!);
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    await _dio.delete<void>('/events/$eventId');
  }
}
