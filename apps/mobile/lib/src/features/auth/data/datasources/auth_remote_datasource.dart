import 'package:dio/dio.dart';

import '../models/auth_response_model.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDatasource {
  Future<AuthResponseModel> signIn({
    required String email,
    required String password,
    String? deviceLabel,
  });

  Future<AuthResponseModel> signUp({
    required String email,
    required String password,
    required String displayName,
    String? deviceLabel,
  });

  Future<AuthResponseModel> refresh({
    required String refreshToken,
    String? deviceLabel,
  });

  Future<void> signOut({required String refreshToken});

  Future<void> signOutAll();

  Future<UserModel> me();

  /// Submits a 6-digit code from the user's verification email. On success
  /// the API responds with the updated user (emailVerifiedAt populated).
  Future<UserModel> verifyEmail({required String code});

  /// Re-issues a verification code for the current user. Server applies a
  /// 1/min/user rate limit; the UI mirrors that with a local cooldown.
  Future<void> resendVerification();

  /// Trigger a password-reset email for the given address. Server returns
  /// 200 regardless of whether the email is on file (enumeration safety).
  Future<void> requestPasswordReset({required String email});

  /// Complete a password reset with the 6-digit code + new password.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  AuthRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<AuthResponseModel> signIn({
    required String email,
    required String password,
    String? deviceLabel,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/sign-in',
      data: {'email': email, 'password': password, 'deviceLabel': ?deviceLabel},
    );
    return AuthResponseModel.fromJson(response.data!);
  }

  @override
  Future<AuthResponseModel> signUp({
    required String email,
    required String password,
    required String displayName,
    String? deviceLabel,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/sign-up',
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
        'deviceLabel': ?deviceLabel,
      },
    );
    return AuthResponseModel.fromJson(response.data!);
  }

  @override
  Future<AuthResponseModel> refresh({
    required String refreshToken,
    String? deviceLabel,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken, 'deviceLabel': ?deviceLabel},
    );
    return AuthResponseModel.fromJson(response.data!);
  }

  @override
  Future<void> signOut({required String refreshToken}) async {
    await _dio.post<void>(
      '/auth/sign-out',
      data: {'refreshToken': refreshToken},
    );
  }

  @override
  Future<void> signOutAll() async {
    await _dio.post<void>('/auth/sign-out-all');
  }

  @override
  Future<UserModel> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');
    return UserModel.fromJson(response.data!);
  }

  @override
  Future<UserModel> verifyEmail({required String code}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/verify-email',
      data: {'code': code},
    );
    return UserModel.fromJson(response.data!);
  }

  @override
  Future<void> resendVerification() async {
    await _dio.post<void>('/auth/resend-verification');
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _dio.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _dio.post<void>(
      '/auth/reset-password',
      data: {'email': email, 'code': code, 'newPassword': newPassword},
    );
  }
}
