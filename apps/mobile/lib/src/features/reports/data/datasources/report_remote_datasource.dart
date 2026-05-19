import 'package:dio/dio.dart';

import '../models/report_model.dart';

/// Driving-adapter interface for the reports remote API.
///
/// Throws [DioException] on network or server errors — does NOT return Either.
/// The repository ([ReportRepositoryImpl]) maps DioExceptions to domain
/// [Failure] types.
abstract class ReportRemoteDatasource {
  /// POST /reports — file a report against a content target.
  Future<ReportModel> fileReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? comment,
  });
}

class ReportRemoteDatasourceImpl implements ReportRemoteDatasource {
  ReportRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<ReportModel> fileReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? comment,
  }) async {
    final body = <String, dynamic>{
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'comment': ?comment,
    };
    final response = await _dio.post<Map<String, dynamic>>(
      '/reports',
      data: body,
    );
    return ReportModel.fromJson(
      response.data!['report'] as Map<String, dynamic>,
    );
  }
}
