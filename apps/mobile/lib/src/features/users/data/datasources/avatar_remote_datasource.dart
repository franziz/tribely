import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/avatar_upload_ticket_model.dart';
import '../models/user_profile_model.dart';

/// Remote datasource for the avatar upload flow.
///
/// Wraps the three backend endpoints that implement the presign → direct PUT
/// → confirm pattern:
///   - POST /users/me/avatar          — returns `{ uploadUrl, storageKey }`
///   - PUT  `uploadUrl`               — direct-to-storage JPEG upload (no API base URL)
///   - POST /users/me/avatar/confirm  — finalises the avatar record, returns UserResponse
///
/// The direct-upload PUT uses an isolated [Dio] instance so the Tribely
/// JWT is never forwarded to the S3 bucket host.
abstract class AvatarRemoteDatasource {
  /// Requests a pre-signed upload URL from the backend.
  ///
  /// Calls POST /users/me/avatar (no body). Returns [AvatarUploadTicketModel]
  /// containing the upload URL and storage key.
  Future<AvatarUploadTicketModel> requestAvatarUpload();

  /// Uploads raw JPEG bytes directly to the storage URL returned by
  /// [requestAvatarUpload].
  ///
  /// The upload must complete before [confirmAvatarUpload] is called.
  /// Uses an isolated Dio without auth interceptors — the presigned URL
  /// itself carries authorization.
  Future<void> putAvatarBytes({
    required String uploadUrl,
    required Uint8List bytes,
  });

  /// Notifies the backend that the direct upload is complete.
  ///
  /// Calls POST /users/me/avatar/confirm with `{ storageKey }`. The backend
  /// transitions the avatar record and returns the updated UserResponse.
  Future<UserProfileModel> confirmAvatarUpload(String storageKey);
}

class AvatarRemoteDatasourceImpl implements AvatarRemoteDatasource {
  AvatarRemoteDatasourceImpl({required Dio apiDio, required Dio storageDio})
    : _apiDio = apiDio,
      _storageDio = storageDio;

  /// Tribely API Dio — carries the auth interceptor + error-interceptor.
  final Dio _apiDio;

  /// Isolated Dio for direct S3 / presigned-URL uploads.
  /// No auth headers — the presigned URL itself carries the credentials.
  final Dio _storageDio;

  @override
  Future<AvatarUploadTicketModel> requestAvatarUpload() async {
    final response = await _apiDio.post<Map<String, dynamic>>(
      '/users/me/avatar',
    );
    return AvatarUploadTicketModel.fromJson(response.data!);
  }

  @override
  Future<void> putAvatarBytes({
    required String uploadUrl,
    required Uint8List bytes,
  }) async {
    await _storageDio.put<void>(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {'Content-Type': 'image/jpeg', 'Content-Length': bytes.length},
        // Tell Dio not to parse body as JSON — the storage endpoint returns
        // an empty 200 body on success.
        responseType: ResponseType.bytes,
      ),
    );
  }

  @override
  Future<UserProfileModel> confirmAvatarUpload(String storageKey) async {
    final response = await _apiDio.post<Map<String, dynamic>>(
      '/users/me/avatar/confirm',
      data: {'storageKey': storageKey},
    );
    return UserProfileModel.fromJson(response.data!);
  }
}
