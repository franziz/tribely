import 'package:dio/dio.dart';

abstract class AccountRemoteDatasource {
  /// Sends `DELETE /users/me`. The server identifies the user from the bearer
  /// token. Throws [DioException] on any network or HTTP error — the
  /// repository is responsible for mapping to [Failure].
  Future<void> deleteAccount();
}

class AccountRemoteDatasourceImpl implements AccountRemoteDatasource {
  AccountRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> deleteAccount() async {
    await _dio.delete<void>('/users/me');
  }
}
