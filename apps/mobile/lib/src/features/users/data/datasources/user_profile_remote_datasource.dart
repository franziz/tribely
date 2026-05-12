import 'package:dio/dio.dart';

import '../models/update_profile_params_model.dart';
import '../models/user_profile_model.dart';

abstract class UserProfileRemoteDatasource {
  /// Fetches a user profile by ID. Used for both own profile (pass own ID)
  /// and other-user profiles. Backend exposes GET /users/:id for both cases.
  Future<UserProfileModel> getUserProfile(String id);
  Future<UserProfileModel> updateMyProfile(UpdateProfileParamsModel params);
}

class UserProfileRemoteDatasourceImpl implements UserProfileRemoteDatasource {
  UserProfileRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<UserProfileModel> getUserProfile(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/users/$id');
    return UserProfileModel.fromJson(response.data!);
  }

  @override
  Future<UserProfileModel> updateMyProfile(
    UpdateProfileParamsModel params,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: params.toJson(),
    );
    return UserProfileModel.fromJson(response.data!);
  }
}
