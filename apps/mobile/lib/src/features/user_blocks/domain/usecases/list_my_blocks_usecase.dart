import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_block_list_page.dart';
import '../repositories/user_block_repository.dart';

class ListMyBlocksParams extends Equatable {
  const ListMyBlocksParams({this.cursor, this.limit = 20});

  final String? cursor;
  final int limit;

  @override
  List<Object?> get props => [cursor, limit];
}

/// Paginated list of users the authenticated user has blocked.
///
/// GET /me/blocks — rows include display name + avatar fetched per-row.
class ListMyBlocksUseCase
    implements UseCase<UserBlockListPage, ListMyBlocksParams> {
  const ListMyBlocksUseCase(this._repository);
  final UserBlockRepository _repository;

  @override
  Future<Either<Failure, UserBlockListPage>> call(ListMyBlocksParams params) =>
      _repository.listMyBlocks(cursor: params.cursor, limit: params.limit);
}
