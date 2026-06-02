import 'package:dio/dio.dart';

import '../models/join_request_model.dart';
import '../models/join_request_with_event_model.dart';
import '../models/join_request_with_requester_model.dart';

/// Driving-adapter interface for the join-requests remote API.
///
/// Throws [DioException] on network or server errors — does NOT return Either.
/// The repository ([JoinRequestRepositoryImpl]) maps DioExceptions to domain
/// [Failure] types, following the established pattern in auth_remote_datasource.dart.
abstract class JoinRequestRemoteDatasource {
  /// POST /events/:eventId/join-requests
  Future<JoinRequestModel> requestToJoin({required String eventId});

  /// POST /join-requests/:id/approve
  Future<JoinRequestModel> approve({required String joinRequestId});

  /// POST /join-requests/:id/reject  (body: { reason })
  Future<JoinRequestModel> decline({
    required String joinRequestId,
    String? reason,
  });

  /// DELETE /join-requests/:id
  Future<void> withdraw({required String joinRequestId});

  /// GET /events/:eventId/join-requests  (host pending list)
  Future<List<JoinRequestWithRequesterModel>> listPendingForEvent({
    required String eventId,
  });

  /// GET /events/:eventId/join-requests?status=approved  (host attending list)
  Future<List<JoinRequestWithRequesterModel>> listApprovedForEvent({
    required String eventId,
  });

  /// GET /me/join-requests?eventId=...  (joiner view; eventId is optional)
  Future<List<JoinRequestWithEventModel>> listMyJoinRequests({String? eventId});

  /// POST /events/:eventId/join-requests/:joinRequestId/remove  (host action)
  ///
  /// Throws [DioException] on network or server errors.
  Future<void> removeAttendee({
    required String eventId,
    required String joinRequestId,
    required String reason,
  });
}

class JoinRequestRemoteDatasourceImpl implements JoinRequestRemoteDatasource {
  JoinRequestRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<JoinRequestModel> requestToJoin({required String eventId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/events/$eventId/join-requests',
    );
    return JoinRequestModel.fromJson(response.data!);
  }

  @override
  Future<JoinRequestModel> approve({required String joinRequestId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/join-requests/$joinRequestId/approve',
    );
    return JoinRequestModel.fromJson(response.data!);
  }

  @override
  Future<JoinRequestModel> decline({
    required String joinRequestId,
    String? reason,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/join-requests/$joinRequestId/reject',
      data: reason != null ? {'reason': reason} : null,
    );
    return JoinRequestModel.fromJson(response.data!);
  }

  @override
  Future<void> withdraw({required String joinRequestId}) async {
    await _dio.delete<void>('/join-requests/$joinRequestId');
  }

  @override
  Future<List<JoinRequestWithRequesterModel>> listPendingForEvent({
    required String eventId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/$eventId/join-requests',
    );
    final list = (response.data!['joinRequests'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return list
        .map(JoinRequestWithRequesterModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<JoinRequestWithEventModel>> listMyJoinRequests({
    String? eventId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/join-requests',
      queryParameters: eventId != null ? {'eventId': eventId} : null,
    );
    final list = (response.data!['joinRequests'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return list.map(JoinRequestWithEventModel.fromJson).toList(growable: false);
  }

  @override
  Future<List<JoinRequestWithRequesterModel>> listApprovedForEvent({
    required String eventId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/$eventId/join-requests',
      queryParameters: {'status': 'approved'},
    );
    final list = (response.data!['joinRequests'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return list
        .map(JoinRequestWithRequesterModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> removeAttendee({
    required String eventId,
    required String joinRequestId,
    required String reason,
  }) async {
    await _dio.post<void>(
      '/events/$eventId/join-requests/$joinRequestId/remove',
      data: {'reason': reason},
    );
  }
}
