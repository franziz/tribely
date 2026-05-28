import 'package:dio/dio.dart';

import '../models/support_ticket_request_model.dart';
import '../models/support_ticket_response_model.dart';

/// Driving-adapter interface for the support remote API.
///
/// Throws [DioException] on network or server errors — does NOT return Either.
/// The repository ([SupportRepositoryImpl]) maps DioExceptions to domain
/// [Failure] types.
abstract class SupportRemoteDataSource {
  /// POST /support/tickets — submit a support ticket.
  Future<SupportTicketResponseModel> submitTicket(
    SupportTicketRequestModel request,
  );
}

class SupportRemoteDataSourceImpl implements SupportRemoteDataSource {
  SupportRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<SupportTicketResponseModel> submitTicket(
    SupportTicketRequestModel request,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/support/tickets',
      data: request.toJson(),
    );
    return SupportTicketResponseModel.fromJson(
      response.data!['ticket'] as Map<String, dynamic>,
    );
  }
}
