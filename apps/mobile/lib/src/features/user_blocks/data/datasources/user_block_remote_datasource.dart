import 'package:dio/dio.dart';

import '../models/user_block_model.dart';

/// Raw API response shape for GET /me/blocks.
class UserBlockListPageRaw {
  const UserBlockListPageRaw({required this.rows, this.nextCursor});

  final List<UserBlockModel> rows;
  final String? nextCursor;
}

/// Driving-adapter interface for the user_blocks remote API.
///
/// Throws [DioException] on network or server errors — does NOT return Either.
/// The repository ([UserBlockRepositoryImpl]) maps DioExceptions to domain
/// [Failure] types.
abstract class UserBlockRemoteDatasource {
  /// POST /me/blocks — block a user.
  Future<UserBlockModel> blockUser({required String blockedUserId});

  /// DELETE /me/blocks/:blockedUserId — unblock a user.
  Future<void> unblockUser({required String blockedUserId});

  /// GET /me/blocks — paginated list of blocks.
  Future<UserBlockListPageRaw> listMyBlocks({String? cursor, int limit = 20});
}

class UserBlockRemoteDatasourceImpl implements UserBlockRemoteDatasource {
  UserBlockRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<UserBlockModel> blockUser({required String blockedUserId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/blocks',
      data: {'blockedUserId': blockedUserId},
    );
    return UserBlockModel.fromJson(
      response.data!['block'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> unblockUser({required String blockedUserId}) async {
    await _dio.delete<void>('/me/blocks/$blockedUserId');
  }

  @override
  Future<UserBlockListPageRaw> listMyBlocks({
    String? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (cursor != null) queryParams['cursor'] = cursor;

    final response = await _dio.get<Map<String, dynamic>>(
      '/me/blocks',
      queryParameters: queryParams,
    );

    final data = response.data!;
    final rawRows = (data['rows'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final rows = rawRows.map(UserBlockModel.fromJson).toList();
    final nextCursor = data['nextCursor'] as String?;
    return UserBlockListPageRaw(rows: rows, nextCursor: nextCursor);
  }
}
