import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/selfie_repository.dart';
import '../datasources/selfie_remote_datasource.dart';

/// Concrete implementation of [SelfieRepository].
///
/// Maps [ServerException] status codes to typed [Failure]s so the use-case
/// layer and presentation layer can switch on failure kind without parsing
/// message strings.
class SelfieRepositoryImpl implements SelfieRepository {
  SelfieRepositoryImpl({required SelfieRemoteDatasource remote})
      : _remote = remote;

  final SelfieRemoteDatasource _remote;

  @override
  Future<Either<Failure, ({String uploadUrl, String storageKey})>>
      requestUploadUrl() async {
    try {
      final model = await _remote.requestUploadUrl();
      return Right((uploadUrl: model.uploadUrl, storageKey: model.storageKey));
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> submitSelfie({
    required String uploadUrl,
    required String storageKey,
    required List<int> jpegBytes,
  }) async {
    try {
      await _remote.uploadJpeg(uploadUrl: uploadUrl, jpegBytes: jpegBytes);
      await _remote.submitSelfie(storageKey: storageKey);
      return const Right(unit);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Failure _mapDioError(DioException e) {
    final inner = e.error;
    if (inner is ServerException) {
      if (inner.code == 'SELFIE_INTAKE_DISABLED') {
        return const SelfieIntakeDisabledFailure();
      }
      if (inner.code == 'SELFIE_NOT_VERIFIED') {
        return const SelfieNotVerifiedFailure();
      }
      return switch (inner.statusCode) {
        401 => AuthFailure(inner.message, code: inner.code),
        403 => ServerFailure(inner.message, statusCode: 403, code: inner.code),
        503 => SelfieIntakeDisabledFailure(inner.message),
        _ => ServerFailure(
            inner.message,
            statusCode: inner.statusCode,
            code: inner.code,
          ),
      };
    }
    if (inner is NetworkException) return NetworkFailure(inner.message);
    return UnknownFailure(e.message ?? 'Unknown error');
  }
}
