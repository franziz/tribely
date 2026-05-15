import 'package:dio/dio.dart';

/// Remote data source for `GET /users/me/capabilities`.
///
/// Throws [DioException] on network or server errors — does NOT return
/// Either. The repository maps DioExceptions to domain [Failure] types,
/// matching the established pattern in [UserProfileRemoteDatasourceImpl].
abstract class UserCapabilitiesRemoteDatasource {
  /// Fetches capability flags for the authenticated user.
  /// Returns the raw response map `{ canPostPrivateVenue: bool }`.
  Future<Map<String, dynamic>> getMyCapabilities();
}

class UserCapabilitiesRemoteDatasourceImpl
    implements UserCapabilitiesRemoteDatasource {
  UserCapabilitiesRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> getMyCapabilities() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/users/me/capabilities',
    );
    return response.data!;
  }
}
