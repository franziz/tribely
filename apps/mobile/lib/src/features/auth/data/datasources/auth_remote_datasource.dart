import 'package:dio/dio.dart';

import '../models/auth_response_model.dart';

abstract class AuthRemoteDatasource {
  Future<AuthResponseModel> signIn({
    required String email,
    required String password,
  });

  Future<AuthResponseModel> signUp({
    required String email,
    required String password,
    required String displayName,
  });
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  AuthRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<AuthResponseModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/sign-in',
      data: {'email': email, 'password': password},
    );
    return AuthResponseModel.fromJson(response.data!);
  }

  @override
  Future<AuthResponseModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/sign-up',
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
      },
    );
    return AuthResponseModel.fromJson(response.data!);
  }
}
