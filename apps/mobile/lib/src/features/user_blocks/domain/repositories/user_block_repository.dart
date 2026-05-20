import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_block.dart';
import '../entities/user_block_list_page.dart';

/// Abstract repository interface for the user_blocks domain.
///
/// All methods return [Either<Failure, T>] — the concrete implementation in
/// data/ catches [DioException] and maps it to the appropriate [Failure] subtype.
///
/// Pure Dart — no Flutter, no Dio, no Riverpod.
abstract class UserBlockRepository {
  /// Block another user.
  ///
  /// POST /me/blocks — idempotent on already-blocked.
  /// Returns [SelfBlockFailure] when [blockedUserId] is the authenticated user.
  Future<Either<Failure, UserBlock>> blockUser({required String blockedUserId});

  /// Remove a block against another user.
  ///
  /// DELETE /me/blocks/:blockedUserId — idempotent; no error if not blocked.
  Future<Either<Failure, void>> unblockUser({required String blockedUserId});

  /// Paginated list of users the authenticated user has blocked.
  ///
  /// GET /me/blocks — rows are enriched with display name + avatar via
  /// per-row [GET /users/:id] calls in the repository implementation.
  Future<Either<Failure, UserBlockListPage>> listMyBlocks({
    String? cursor,
    int limit = 20,
  });
}
