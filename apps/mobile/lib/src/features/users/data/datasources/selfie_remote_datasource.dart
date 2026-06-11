import 'package:dio/dio.dart';

import '../models/selfie_upload_presign_model.dart';

/// Remote datasource for the selfie verification intake flow.
///
/// Wraps the two backend endpoints:
///   - POST /auth/selfie — returns `{ uploadUrl, storageKey }`
///   - PUT to uploadUrl (JPEG bytes, direct S3/storage upload — not via ApiClient)
///   - POST /auth/selfie/submit — finalises the intake record
///
/// The direct-upload PUT uses an isolated [Dio] instance so the Tribely
/// JWT is never forwarded to the S3 bucket host.
abstract class SelfieRemoteDatasource {
  /// Requests a pre-signed upload URL from the backend.
  ///
  /// Returns [SelfieUploadPresignModel] containing the upload URL and storage
  /// key. Throws on SELFIE_INTAKE_DISABLED (503) or any auth error.
  Future<SelfieUploadPresignModel> requestUploadUrl();

  /// Uploads raw JPEG bytes directly to the storage URL returned by
  /// [requestUploadUrl]. The upload must complete before [submitSelfie] is
  /// called.
  Future<void> uploadJpeg({
    required String uploadUrl,
    required List<int> jpegBytes,
  });

  /// Notifies the backend that the direct upload is complete. The backend
  /// transitions the selfie record to `pending` review status.
  Future<void> submitSelfie({required String storageKey});
}

class SelfieRemoteDatasourceImpl implements SelfieRemoteDatasource {
  SelfieRemoteDatasourceImpl({
    required Dio apiDio,
    required Dio storageDio,
  })  : _apiDio = apiDio,
        _storageDio = storageDio;

  /// Tribely API Dio — carries the auth interceptor + error-interceptor.
  final Dio _apiDio;

  /// Isolated Dio for direct S3 / presigned-URL uploads.
  /// No auth headers — the presigned URL itself carries the credentials.
  final Dio _storageDio;

  @override
  Future<SelfieUploadPresignModel> requestUploadUrl() async {
    final response = await _apiDio.post<Map<String, dynamic>>('/auth/selfie');
    return SelfieUploadPresignModel.fromJson(response.data!);
  }

  @override
  Future<void> uploadJpeg({
    required String uploadUrl,
    required List<int> jpegBytes,
  }) async {
    await _storageDio.put<void>(
      uploadUrl,
      data: Stream.fromIterable([jpegBytes]),
      options: Options(
        headers: {
          'Content-Type': 'image/jpeg',
          'Content-Length': jpegBytes.length,
        },
        // Tell Dio not to parse body as JSON — the storage endpoint returns
        // an empty 200 body on success.
        responseType: ResponseType.bytes,
      ),
    );
  }

  @override
  Future<void> submitSelfie({required String storageKey}) async {
    await _apiDio.post<void>(
      '/auth/selfie/submit',
      data: {'storageKey': storageKey},
    );
  }
}
