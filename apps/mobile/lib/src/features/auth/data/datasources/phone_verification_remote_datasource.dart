import 'package:dio/dio.dart';

import '../models/user_model.dart';

/// Remote datasource for the phone OTP verification flow.
///
/// Interface + impl colocated (Reso Coder pattern for thin adapters where a
/// separate file would add no information-hiding value).
abstract class PhoneVerificationRemoteDatasource {
  /// POST /auth/phone/start — sends a 6-digit OTP to [phone] (E.164).
  Future<void> startVerification({required String phone});

  /// POST /auth/phone/verify — submits [code] for [phone]. On success returns
  /// the updated user with `phoneVerifiedAt` populated.
  Future<UserModel> verify({required String phone, required String code});
}

class PhoneVerificationRemoteDatasourceImpl
    implements PhoneVerificationRemoteDatasource {
  const PhoneVerificationRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> startVerification({required String phone}) async {
    await _dio.post<void>('/auth/phone/start', data: {'phone': phone});
  }

  @override
  Future<UserModel> verify({
    required String phone,
    required String code,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/phone/verify',
      data: {'phone': phone, 'code': code},
    );
    return UserModel.fromJson(response.data!);
  }
}
