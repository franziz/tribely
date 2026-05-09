import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';
import '../storage/token_storage.dart';

class ApiClient {
  ApiClient({required AppConfig config, required TokenStorage tokenStorage})
      : _tokenStorage = tokenStorage,
        dio = Dio(
          BaseOptions(
            baseUrl: config.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            contentType: 'application/json',
            // Skip ngrok's "browser warning" interstitial when tunneling
            // through ngrok free-tier URLs. Harmless on non-ngrok backends.
            // Required because iOS's native HTTP stack can send a User-Agent
            // ngrok mistakes for a browser.
            headers: const {'ngrok-skip-browser-warning': 'true'},
          ),
        ) {
    dio.interceptors.add(_AuthInterceptor(_tokenStorage));
    dio.interceptors.add(_ErrorInterceptor());
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        compact: true,
      ),
    );
  }

  final Dio dio;
  final TokenStorage _tokenStorage;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokenStorage);
  final TokenStorage _tokenStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response == null) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: const NetworkException('No response from server'),
          type: err.type,
        ),
      );
      return;
    }

    final data = response.data;
    String message = 'Server error';
    String? code;
    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      final errMap = data['error'] as Map<String, dynamic>;
      message = (errMap['message'] as String?) ?? message;
      code = errMap['code'] as String?;
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: response,
        error: ServerException(
          message,
          statusCode: response.statusCode,
          code: code,
        ),
        type: err.type,
      ),
    );
  }
}
