import 'package:dio/dio.dart';

import '../models/create_event_params_model.dart';
import '../models/event_model.dart';

/// Driving-adapter interface for the events remote API.
///
/// This datasource throws [DioException] on network or server errors — it does
/// NOT return Either. The repository (Brief 4 / EventRepositoryImpl) maps
/// DioExceptions to domain [Failure] types. This matches the established
/// pattern in auth_remote_datasource.dart.
///
/// Only [createEvent] is implemented for the v1 create-event flow. Read/update/
/// delete/list methods will be added in future tickets.
abstract class EventRemoteDatasource {
  Future<EventModel> createEvent(CreateEventParamsModel params);
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
}
