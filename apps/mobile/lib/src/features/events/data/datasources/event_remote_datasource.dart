import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/cover_photo_upload_ticket_model.dart';
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

  // ---------------------------------------------------------------------------
  // Cover photo upload (presign → direct PUT, no confirm step)
  // ---------------------------------------------------------------------------

  /// Requests a pre-signed upload URL from the backend for a cover photo.
  ///
  /// Calls POST /events/cover-photo?contentType=`<contentType>`. Returns a
  /// [CoverPhotoUploadTicketModel] containing the upload URL and storage key.
  ///
  /// The creation endpoint fuses the storage key record — there is no separate
  /// confirm call; the key is supplied directly to the create-event body.
  Future<CoverPhotoUploadTicketModel> requestCoverPhotoUpload(
    String contentType,
  );

  /// Uploads raw bytes directly to the presigned storage URL.
  ///
  /// Uses an isolated Dio without auth interceptors — the presigned URL itself
  /// carries authorization. [contentType] must match what was used in
  /// [requestCoverPhotoUpload] (always `image/jpeg` after downscaling).
  ///
  /// [onSendProgress] is an optional Dio [ProgressCallback] — receives
  /// (sent, total) so callers can drive a determinate [LinearProgressIndicator].
  Future<void> putCoverBytes({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
    ProgressCallback? onSendProgress,
  });

  /// Replaces the cover photo key on an existing event.
  ///
  /// Calls PUT /events/:id/cover-photo with body `{coverPhotoStorageKey}`.
  /// Returns the updated [EventModel] (bare event shape — same as [createEvent]).
  /// Throws [DioException] on network or server errors — the repository maps
  /// to domain [Failure] types.
  Future<EventModel> replaceCoverPhoto({
    required String eventId,
    required String storageKey,
  });
}

class EventRemoteDatasourceImpl implements EventRemoteDatasource {
  EventRemoteDatasourceImpl({required Dio apiDio, required Dio storageDio})
    : _apiDio = apiDio,
      _storageDio = storageDio;

  /// Tribely API Dio — carries the auth interceptor + error-interceptor.
  final Dio _apiDio;

  /// Isolated Dio for direct S3 / presigned-URL uploads.
  /// No auth headers — the presigned URL itself carries the credentials.
  final Dio _storageDio;

  @override
  Future<EventModel> createEvent(CreateEventParamsModel params) async {
    final response = await _apiDio.post<Map<String, dynamic>>(
      '/events',
      data: params.toJson(),
    );
    return EventModel.fromJson(response.data!);
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    await _apiDio.delete<void>('/events/$eventId');
  }

  @override
  Future<CoverPhotoUploadTicketModel> requestCoverPhotoUpload(
    String contentType,
  ) async {
    final response = await _apiDio.post<Map<String, dynamic>>(
      '/events/cover-photo',
      queryParameters: {'contentType': contentType},
    );
    return CoverPhotoUploadTicketModel.fromJson(response.data!);
  }

  @override
  Future<EventModel> replaceCoverPhoto({
    required String eventId,
    required String storageKey,
  }) async {
    final response = await _apiDio.put<Map<String, dynamic>>(
      '/events/$eventId/cover-photo',
      data: {'coverPhotoStorageKey': storageKey},
    );
    return EventModel.fromJson(response.data!);
  }

  @override
  Future<void> putCoverBytes({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
    ProgressCallback? onSendProgress,
  }) async {
    await _storageDio.put<void>(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      onSendProgress: onSendProgress,
      options: Options(
        headers: {'Content-Type': contentType, 'Content-Length': bytes.length},
        // Tell Dio not to parse body as JSON — the storage endpoint returns
        // an empty 200 body on success.
        responseType: ResponseType.bytes,
      ),
    );
  }
}
