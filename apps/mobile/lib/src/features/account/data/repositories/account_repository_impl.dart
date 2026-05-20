import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_remote_datasource.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({required AccountRemoteDatasource remote})
    : _remote = remote;

  final AccountRemoteDatasource _remote;

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await _remote.deleteAccount();
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Failure _mapDioError(DioException e) {
    final inner = e.error;
    if (inner is ServerException) {
      final code = inner.statusCode;
      if (code == 401) {
        return AuthFailure(inner.message, code: inner.code);
      }
      return ServerFailure(inner.message, statusCode: code, code: inner.code);
    }
    if (inner is NetworkException) {
      return NetworkFailure(inner.message);
    }
    return UnknownFailure(e.message ?? 'Unknown error');
  }
}
