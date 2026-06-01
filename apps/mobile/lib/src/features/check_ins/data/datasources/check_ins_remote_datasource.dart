import 'package:dio/dio.dart';

import '../models/pending_check_in_model.dart';

/// Driving-adapter interface for the check-ins remote API.
///
/// Throws [DioException] on network or server errors — does NOT return Either.
/// The repository ([CheckInsRepositoryImpl]) maps DioExceptions to domain
/// [Failure] types, following the established pattern across other features.
///
/// NOTE: The endpoints targeted here (`/me/post-event-check-ins` and the
/// acknowledge/flag sub-routes) are planned for Wave 4 (Brief B3) and do not
/// yet exist on the server. Integration tests use a mock implementation; the
/// real wiring lands when Brief B3 ships.
abstract class CheckInsRemoteDataSource {
  /// `GET /me/post-event-check-ins`
  ///
  /// Returns the authenticated user's pending post-event check-ins ordered
  /// by [createdAt] descending. Returns an empty list when there are none.
  Future<List<PendingCheckInModel>> getPending();

  /// `POST /me/post-event-check-ins/:id/acknowledge`
  ///
  /// Marks the check-in as acknowledged (attendee is safe). No request body.
  Future<void> acknowledge(String id);

  /// `POST /me/post-event-check-ins/:id/flag`
  ///
  /// Flags the check-in for safety review.
  /// Body: `{ "reportBody": <string>, "disclaimerAcknowledged": <bool> }`.
  Future<void> flag(
    String id,
    String reportBody,
    bool disclaimerAcknowledged,
  );
}

class CheckInsRemoteDataSourceImpl implements CheckInsRemoteDataSource {
  CheckInsRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<PendingCheckInModel>> getPending() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/post-event-check-ins',
    );
    final list = (response.data!['checkIns'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return list.map(PendingCheckInModel.fromJson).toList(growable: false);
  }

  @override
  Future<void> acknowledge(String id) async {
    await _dio.post<void>('/me/post-event-check-ins/$id/acknowledge');
  }

  @override
  Future<void> flag(
    String id,
    String reportBody,
    bool disclaimerAcknowledged,
  ) async {
    await _dio.post<void>(
      '/me/post-event-check-ins/$id/flag',
      data: {
        'reportBody': reportBody,
        'disclaimerAcknowledged': disclaimerAcknowledged,
      },
    );
  }
}
