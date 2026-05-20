import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../users/data/datasources/user_profile_remote_datasource.dart';
import '../../domain/entities/blocked_user_summary.dart';
import '../../domain/entities/user_block.dart';
import '../../domain/entities/user_block_list_page.dart';
import '../../domain/repositories/user_block_repository.dart';
import '../datasources/user_block_remote_datasource.dart';
import '../models/user_block_model.dart';

/// Data-layer implementation of [UserBlockRepository].
///
/// The backend [GET /me/blocks] returns only [blockedUserId] without display
/// data. This repository enriches each row by calling [GET /users/:id] per
/// row via [UserProfileRemoteDatasource], with a best-effort pattern: if the
/// profile fetch fails the row still renders with null display data.
///
/// Block count is expected to be low (MVP users ≤ ~20 blocks), so per-row
/// fetches are acceptable. Revisit with a server-side join if list sizes grow.
class UserBlockRepositoryImpl implements UserBlockRepository {
  const UserBlockRepositoryImpl({
    required UserBlockRemoteDatasource remote,
    required UserProfileRemoteDatasource profileRemote,
  }) : _remote = remote,
       _profileRemote = profileRemote;

  final UserBlockRemoteDatasource _remote;
  final UserProfileRemoteDatasource _profileRemote;

  @override
  Future<Either<Failure, UserBlock>> blockUser({
    required String blockedUserId,
  }) async {
    try {
      final model = await _remote.blockUser(blockedUserId: blockedUserId);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unblockUser({
    required String blockedUserId,
  }) async {
    try {
      await _remote.unblockUser(blockedUserId: blockedUserId);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserBlockListPage>> listMyBlocks({
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final raw = await _remote.listMyBlocks(cursor: cursor, limit: limit);

      // Enrich each row with display data (best-effort, per-row).
      final summaries = await Future.wait(raw.rows.map((m) => _enrichRow(m)));

      return Right(
        UserBlockListPage(rows: summaries, nextCursor: raw.nextCursor),
      );
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Enrichment — best-effort profile fetch
  // ---------------------------------------------------------------------------

  /// Attempts to fetch the blocked user's display name + avatar via
  /// [UserProfileRemoteDatasource.getUserProfile].
  ///
  /// On failure (any error), falls back to a [BlockedUserSummary] with null
  /// display-data fields. The Blocked Users page renders a graceful fallback.
  Future<BlockedUserSummary> _enrichRow(UserBlockModel model) async {
    try {
      final profile = await _profileRemote.getUserProfile(model.blockedUserId);
      return BlockedUserSummary(
        blockId: model.id,
        blockedUserId: model.blockedUserId,
        createdAt: model.createdAt,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
      );
    } catch (_) {
      // Profile fetch failed — return partial row with null display data.
      return BlockedUserSummary(
        blockId: model.id,
        blockedUserId: model.blockedUserId,
        createdAt: model.createdAt,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Dio → Failure mapping
  // ---------------------------------------------------------------------------

  Failure _mapDioError(DioException e) {
    final inner = e.error;

    if (inner is NetworkException) {
      return NetworkFailure(inner.message);
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure('Request timed out');
    }

    if (inner is ServerException) {
      final statusCode = inner.statusCode;
      final code = inner.code;
      final message = inner.message;

      switch (statusCode) {
        case 401:
          return AuthFailure(message, code: code);

        case 403:
          if (code == 'EMAIL_NOT_VERIFIED') {
            return EmailNotVerifiedFailure(message, code: code);
          }
          return ServerFailure(message, statusCode: 403, code: code);

        case 422:
          // 422 with SELF_BLOCK code — user attempted to block themselves.
          return SelfBlockFailure(message, code: code);

        case 400:
          return ValidationFailure(message, code: code);

        default:
          return ServerFailure(message, statusCode: statusCode, code: code);
      }
    }

    return UnknownFailure(e.message ?? 'Unknown error');
  }
}
