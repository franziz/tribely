import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/cover_photo_repository.dart'
    show CoverPhotoProgressCallback, CoverPhotoRepository;
import '../datasources/event_remote_datasource.dart';
import '../utils/cover_photo_compressor.dart';

/// 15 MB pre-pick size cap. Bytes above this threshold are rejected before
/// downscale — a [ValidationFailure] with code 'COVER_PHOTO_TOO_LARGE' is
/// returned so the picker (Brief 3) can surface a user-friendly error.
const _kMaxInputBytes = 15 * 1024 * 1024;

class CoverPhotoRepositoryImpl implements CoverPhotoRepository {
  const CoverPhotoRepositoryImpl({
    required EventRemoteDatasource remote,
    required CoverPhotoCompressor compressor,
  }) : _remote = remote,
       _compressor = compressor;

  final EventRemoteDatasource _remote;
  final CoverPhotoCompressor _compressor;

  /// Orchestrates the two-step cover photo upload pipeline:
  ///   1. Validate input size (≤ 15 MB).
  ///   2. Downscale with [CoverPhotoCompressor] → always produces JPEG.
  ///   3. POST /events/cover-photo?contentType=image/jpeg — get presigned URL.
  ///   4. PUT bytes directly to storage — no Tribely JWT forwarded.
  ///
  /// Returns the [storageKey] on success. The caller (create-event wizard)
  /// fuses the key into the event body — there is no separate confirm call.
  @override
  Future<Either<Failure, String>> uploadCoverPhoto(
    Uint8List croppedBytes, {
    CoverPhotoProgressCallback? onProgress,
  }) async {
    // Step 1 — size cap guard
    if (croppedBytes.length > _kMaxInputBytes) {
      return const Left(
        ValidationFailure(
          'Cover photo must be under 15 MB.',
          code: 'COVER_PHOTO_TOO_LARGE',
        ),
      );
    }

    // Step 2 — downscale (output is always JPEG)
    final Uint8List compressed;
    try {
      compressed = await _compressor.compress(croppedBytes);
    } catch (e) {
      return Left(UnknownFailure('Cover photo compression failed: $e'));
    }

    // Step 3 — presign with image/jpeg (the post-downscale type)
    final String uploadUrl;
    final String storageKey;
    try {
      final ticket = await _remote.requestCoverPhotoUpload(
        CoverPhotoCompressor.outputMimeType,
      );
      uploadUrl = ticket.uploadUrl;
      storageKey = ticket.storageKey;
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }

    // Step 4 — direct PUT to storage (isolated Dio — no Tribely JWT)
    try {
      await _remote.putCoverBytes(
        uploadUrl: uploadUrl,
        bytes: compressed,
        contentType: CoverPhotoCompressor.outputMimeType,
        onSendProgress: onProgress != null
            ? (sent, total) => onProgress(sent, total)
            : null,
      );
    } on DioException catch (e) {
      // Storage PUT errors are network/provider errors, not Tribely API errors.
      final inner = e.error;
      if (inner is NetworkException) {
        return Left(NetworkFailure(inner.message));
      }
      return Left(
        ServerFailure(
          e.message ?? 'Cover photo storage upload failed',
          code: 'COVER_PHOTO_PUT_FAILED',
        ),
      );
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }

    return Right(storageKey);
  }

  @override
  Future<Either<Failure, Event>> replaceCoverPhoto({
    required String eventId,
    required String storageKey,
  }) async {
    try {
      final model = await _remote.replaceCoverPhoto(
        eventId: eventId,
        storageKey: storageKey,
      );
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
        400 => ValidationFailure(inner.message, code: inner.code),
        401 => AuthFailure(inner.message, code: inner.code),
        403 => ServerFailure(inner.message, statusCode: 403, code: inner.code),
        404 => NotFoundFailure(inner.message, code: inner.code),
        409 => ConflictFailure(
          inner.message,
          subcode: inner.code ?? 'CONFLICT',
          code: inner.code,
        ),
        // 413 is a legacy path from an earlier server-side size gate. The
        // current API returns 422 UNPROCESSABLE with subcode COVER_PHOTO_TOO_LARGE
        // for both create-event and replace-cover-photo. TRI-305.
        413 => ValidationFailure(
          inner.message,
          code: 'COVER_PHOTO_TOO_LARGE',
        ),
        422 => inner.code == 'COVER_PHOTO_TOO_LARGE'
            ? const ValidationFailure(
                'Cover photo must be under 5 MB.',
                code: 'COVER_PHOTO_TOO_LARGE',
              )
            : ValidationFailure(inner.message, code: inner.code),
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
