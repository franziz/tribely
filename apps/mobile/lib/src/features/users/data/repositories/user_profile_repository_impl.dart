import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/ports/user_profile_port.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/avatar_remote_datasource.dart';
import '../datasources/user_profile_remote_datasource.dart';
import '../models/update_profile_params_model.dart';

class UserProfileRepositoryImpl
    implements UserProfileRepository, UserProfilePort {
  UserProfileRepositoryImpl({
    required UserProfileRemoteDatasource remote,
    required AvatarRemoteDatasource avatarRemote,
  }) : _remote = remote,
       _avatarRemote = avatarRemote;

  final UserProfileRemoteDatasource _remote;
  final AvatarRemoteDatasource _avatarRemote;

  @override
  Future<Either<Failure, UserProfile>> getUserProfile(String id) =>
      _fetchProfile(id);

  @override
  Future<Either<Failure, UserProfile>> updateMyProfile(
    UpdateProfileParams params,
  ) async {
    try {
      final model = await _remote.updateMyProfile(
        UpdateProfileParamsModel.fromDomain(params),
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  /// Orchestrates the three-step avatar upload flow:
  ///   1. POST /users/me/avatar          — get presigned uploadUrl + storageKey
  ///   2. PUT  `uploadUrl`               — upload JPEG bytes directly to storage
  ///   3. POST /users/me/avatar/confirm  — confirm upload, receive updated profile
  ///
  /// Fails fast on any step. Each [DioException] is mapped to a typed [Failure].
  /// The PUT-to-storage failure is caught separately — it is not an API error
  /// and may originate from a different host (S3 / GCS).
  @override
  Future<Either<Failure, UserProfile>> uploadAvatar(Uint8List bytes) async {
    // Step 1 — presign
    final AvatarUploadTicket ticket;
    try {
      final model = await _avatarRemote.requestAvatarUpload();
      ticket = (uploadUrl: model.uploadUrl, storageKey: model.storageKey);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }

    // Step 2 — direct PUT to storage (isolated Dio — no Tribely JWT)
    try {
      await _avatarRemote.putAvatarBytes(
        uploadUrl: ticket.uploadUrl,
        bytes: bytes,
      );
    } on DioException catch (e) {
      // Storage PUT errors are network/provider errors, not Tribely API errors.
      // Map them to ServerFailure / NetworkFailure without expecting a ServerException.
      final inner = e.error;
      if (inner is NetworkException) {
        return Left(NetworkFailure(inner.message));
      }
      return Left(
        ServerFailure(
          e.message ?? 'Avatar storage upload failed',
          code: 'AVATAR_PUT_FAILED',
        ),
      );
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }

    // Step 3 — confirm
    try {
      final model = await _avatarRemote.confirmAvatarUpload(ticket.storageKey);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, UserProfile>> _fetchProfile(String id) async {
    try {
      final model = await _remote.getUserProfile(id);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Failure _mapDioError(DioException e) {
    final inner = e.error;
    if (inner is ServerException) {
      return switch (inner.statusCode) {
        401 => AuthFailure(inner.message, code: inner.code),
        404 => ServerFailure(inner.message, statusCode: 404, code: inner.code),
        422 => ValidationFailure(inner.message, code: inner.code),
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

/// Internal named record for the presign result — used only within this
/// repository to carry the ticket from Step 1 to Steps 2 & 3.
typedef AvatarUploadTicket = ({String uploadUrl, String storageKey});
